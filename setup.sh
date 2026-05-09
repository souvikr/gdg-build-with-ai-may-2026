#!/bin/bash
set -e

PROJECT_ID="gdg-mauritius-build-with-ai"
REGION="us-central1"
BUCKET_NAME="${PROJECT_ID}-docs"
TOPIC_NAME="doc-uploads-topic"
SERVICE_NAME="doc-processor"
SERVICE_ACCOUNT="doc-processor-sa@${PROJECT_ID}.iam.gserviceaccount.com"
BQ_DATASET="doc_processing"
BQ_TABLE="metadata"

echo "Setting Google Cloud project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

echo "Enabling required APIs..."
gcloud services enable run.googleapis.com \
    pubsub.googleapis.com \
    storage.googleapis.com \
    bigquery.googleapis.com \
    cloudbuild.googleapis.com \
    eventarc.googleapis.com

echo "Creating BigQuery Dataset ($BQ_DATASET)..."
if ! bq.cmd ls | grep -q "\b$BQ_DATASET\b"; then
    bq.cmd mk -d --location=$REGION "${PROJECT_ID}:${BQ_DATASET}"
else
    echo "Dataset $BQ_DATASET already exists."
fi

echo "Creating BigQuery Table ($BQ_TABLE)..."
if ! bq.cmd ls "${PROJECT_ID}:${BQ_DATASET}" | grep -q "\b$BQ_TABLE\b"; then
    bq.cmd mk -t "${PROJECT_ID}:${BQ_DATASET}.${BQ_TABLE}" filename:STRING,processed_date:TIMESTAMP,word_count:INTEGER,tags:STRING,bucket:STRING
else
    echo "Table $BQ_TABLE already exists."
fi

echo "Creating Pub/Sub Topic ($TOPIC_NAME)..."
if ! gcloud pubsub topics list --filter="name:projects/$PROJECT_ID/topics/$TOPIC_NAME" --format="value(name)" | grep -q "$TOPIC_NAME"; then
    gcloud pubsub topics create $TOPIC_NAME
else
    echo "Topic $TOPIC_NAME already exists."
fi

echo "Creating Cloud Storage Bucket ($BUCKET_NAME)..."
if ! gcloud storage ls | grep -q "gs://$BUCKET_NAME/"; then
    gcloud storage buckets create gs://$BUCKET_NAME/ --location=$REGION
else
    echo "Bucket $BUCKET_NAME already exists."
fi

echo "Creating Service Account ($SERVICE_ACCOUNT) for Cloud Run..."
if ! gcloud iam service-accounts list --filter="email:$SERVICE_ACCOUNT" --format="value(email)" | grep -q "$SERVICE_ACCOUNT"; then
    gcloud iam service-accounts create doc-processor-sa --display-name="Doc Processor Service Account"
    
    echo "Granting BigQuery roles to the Service Account..."
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT" \
        --role="roles/bigquery.dataEditor"
        
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT" \
        --role="roles/bigquery.jobUser"
else
    echo "Service account $SERVICE_ACCOUNT already exists."
fi

echo "Configuring GCS Bucket to publish events to Pub/Sub..."
if ! gcloud storage buckets notifications list gs://$BUCKET_NAME/ | grep -q "$TOPIC_NAME"; then
    gcloud storage buckets notifications create gs://$BUCKET_NAME/ --topic=$TOPIC_NAME --payload-format=json
else
    echo "GCS notifications already configured."
fi

echo "Deploying Cloud Run Service ($SERVICE_NAME)..."
gcloud run deploy $SERVICE_NAME \
    --source . \
    --region $REGION \
    --service-account $SERVICE_ACCOUNT \
    --set-env-vars="PROJECT_ID=$PROJECT_ID,BQ_DATASET=$BQ_DATASET,BQ_TABLE=$BQ_TABLE" \
    --allow-unauthenticated \
    --quiet

SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.url)")
echo "Cloud Run Service deployed at: $SERVICE_URL"

echo "Creating Pub/Sub Push Subscription..."
SUBSCRIPTION_NAME="${TOPIC_NAME}-push-sub"
if ! gcloud pubsub subscriptions list --filter="name:projects/$PROJECT_ID/subscriptions/$SUBSCRIPTION_NAME" --format="value(name)" | grep -q "$SUBSCRIPTION_NAME"; then
    gcloud pubsub subscriptions create $SUBSCRIPTION_NAME \
        --topic $TOPIC_NAME \
        --push-endpoint="${SERVICE_URL}/" \
        --push-auth-service-account=$SERVICE_ACCOUNT
else
    echo "Subscription $SUBSCRIPTION_NAME already exists. Updating push endpoint..."
    gcloud pubsub subscriptions update $SUBSCRIPTION_NAME \
        --push-endpoint="${SERVICE_URL}/" \
        --push-auth-service-account=$SERVICE_ACCOUNT
fi

echo "Deployment Complete!"
echo "Test the pipeline by uploading a file to gs://$BUCKET_NAME/"
