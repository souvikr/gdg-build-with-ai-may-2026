#!/bin/bash
set -e

if [ -f .env ]; then
  source .env
else
  echo "Error: .env file not found."
  exit 1
fi
BUCKET_NAME="${PROJECT_ID}-doc-uploads"

echo "Creating a test document..."
echo "This is a test document for the serverless pipeline." > test_document.pdf

echo "Uploading test document to gs://$BUCKET_NAME/ ..."
# Using gcloud storage instead of gsutil
gcloud storage cp test_document.pdf gs://$BUCKET_NAME/

echo "Waiting 15 seconds for Cloud Run to process the file and write to BigQuery..."
sleep 15

echo "Querying BigQuery to verify the metadata insertion..."
echo "SELECT filename, upload_date, tags, word_count FROM \`${PROJECT_ID}.pipeline_data.processed_docs\` WHERE filename = 'test_document.pdf' ORDER BY upload_date DESC LIMIT 5" | bq.cmd query --use_legacy_sql=false

echo "Verification complete! If you see a row above with 'test_document.pdf', the pipeline is fully working."
