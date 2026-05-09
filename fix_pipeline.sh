#!/bin/bash
set -e

PROJECT_ID="gdg-mauritius-build-with-ai"
REGION="us-central1"

# Corrected Resource Names based on requirements
BUCKET_NAME="${PROJECT_ID}-doc-uploads"
TOPIC_NAME="doc-processing-topic"
SUBSCRIPTION_NAME="doc-processing-sub"
SERVICE_NAME="doc-processor"
BQ_DATASET="pipeline_data"
BQ_TABLE="processed_docs"
SERVICE_ACCOUNT="${SERVICE_NAME}-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Applying fixes to match required architecture..."

# 1. Create correct BigQuery Dataset and Table
echo "Creating BigQuery Dataset ($BQ_DATASET)..."
if ! bq.cmd ls | grep -q "\b$BQ_DATASET\b"; then
    bq.cmd mk -d --location=$REGION "${PROJECT_ID}:${BQ_DATASET}"
fi

echo "Creating BigQuery Table ($BQ_TABLE) with correct schema..."
if ! bq.cmd ls "${PROJECT_ID}:${BQ_DATASET}" | grep -q "\b$BQ_TABLE\b"; then
    bq.cmd mk -t "${PROJECT_ID}:${BQ_DATASET}.${BQ_TABLE}" filename:STRING,upload_date:TIMESTAMP,tags:STRING,word_count:INTEGER
fi

# 2. Create correct Pub/Sub Topic
echo "Creating Pub/Sub Topic ($TOPIC_NAME)..."
if ! gcloud pubsub topics list --filter="name:projects/$PROJECT_ID/topics/$TOPIC_NAME" --format="value(name)" | grep -q "$TOPIC_NAME"; then
    gcloud pubsub topics create $TOPIC_NAME
fi

# 3. Create correct GCS Bucket
echo "Creating Cloud Storage Bucket ($BUCKET_NAME)..."
if ! gcloud storage ls | grep -q "gs://$BUCKET_NAME/"; then
    gcloud storage buckets create gs://$BUCKET_NAME/ --location=$REGION
fi

# 4. Service Account (ensure it exists)
echo "Setting up Service Account..."
if ! gcloud iam service-accounts list --filter="email:$SERVICE_ACCOUNT" --format="value(email)" | grep -q "$SERVICE_ACCOUNT"; then
    gcloud iam service-accounts create ${SERVICE_NAME}-sa --display-name="Doc Processor SA"
    
    echo "Granting BigQuery roles..."
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/bigquery.dataEditor"
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/bigquery.jobUser"
fi

# 5. GCS Notifications to correct topic
echo "Configuring GCS Bucket to publish events to Pub/Sub..."
if ! gcloud storage buckets notifications list gs://$BUCKET_NAME/ | grep -q "$TOPIC_NAME"; then
    gcloud storage buckets notifications create gs://$BUCKET_NAME/ --topic=$TOPIC_NAME --payload-format=json
fi

# 6. Deploy Cloud Run with updated environment variables
echo "Deploying Cloud Run Service ($SERVICE_NAME) with corrected code and env vars..."
gcloud run deploy $SERVICE_NAME \
    --source . \
    --region $REGION \
    --service-account $SERVICE_ACCOUNT \
    --set-env-vars="PROJECT_ID=$PROJECT_ID,BQ_DATASET=$BQ_DATASET,BQ_TABLE=$BQ_TABLE" \
    --allow-unauthenticated \
    --quiet

SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.url)")
echo "Cloud Run Service deployed at: $SERVICE_URL"

# 7. Create/Update Pub/Sub Push Subscription
echo "Creating Pub/Sub Push Subscription ($SUBSCRIPTION_NAME)..."
if ! gcloud pubsub subscriptions list --filter="name:projects/$PROJECT_ID/subscriptions/$SUBSCRIPTION_NAME" --format="value(name)" | grep -q "$SUBSCRIPTION_NAME"; then
    gcloud pubsub subscriptions create $SUBSCRIPTION_NAME \
        --topic $TOPIC_NAME \
        --push-endpoint="${SERVICE_URL}/" \
        --push-auth-service-account=$SERVICE_ACCOUNT
else
    echo "Updating existing subscription push endpoint..."
    gcloud pubsub subscriptions update $SUBSCRIPTION_NAME \
        --push-endpoint="${SERVICE_URL}/" \
        --push-auth-service-account=$SERVICE_ACCOUNT
fi

echo "Fix completed! The pipeline now exactly matches the required structure."
