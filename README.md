# Serverless Document Processing Pipeline

An event-driven document processing pipeline built on Google Cloud. This project demonstrates how to ingest files via Google Cloud Storage, trigger events via Pub/Sub, process data with a Python-based Cloud Run service, and store extracted metadata in BigQuery.

## Architecture

1. **Ingestion**: Users upload files to a Google Cloud Storage bucket (`[PROJECT_ID]-doc-uploads`).
2. **Trigger**: GCS sends a notification event to a Pub/Sub topic (`doc-processing-topic`) whenever a new object is created.
3. **Processor**: A Python-based Cloud Run service (`doc-processor`) acts as a push subscriber to the topic. It receives the event, simulates OCR processing, and extracts document metadata.
4. **Storage**: The metadata (filename, upload date, tags, word count) is streamed into a BigQuery table (`pipeline_data.processed_docs`).

## Repository Structure

* `src/main.py`: The Python Flask web service designed for Cloud Run.
* `src/requirements.txt`: Python dependencies.
* `Dockerfile`: Container configuration for the service.
* `setup.sh`: Bash script for initial infrastructure provisioning (older version).
* `fix_pipeline.sh`: The primary deployment script that sets up all GCP resources with the exact expected naming conventions and deploys the Cloud Run service.
* `verify.sh`: A script to test the end-to-end pipeline by uploading a dummy document and querying BigQuery.
* `query_bq.sh`: A helper script to view the BigQuery table schema and fetch recent rows.

## Prerequisites

* [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install) installed and configured.
* A Google Cloud Project with billing enabled.
* Git Bash or a compatible bash terminal.

## Setup Instructions

1. Clone the repository and navigate into the project directory:
   ```bash
   git clone https://github.com/souvikr/gdg-build-with-ai-may-2026.git
   cd gdg-build-with-ai-may-2026
   ```

2. Ensure you are authenticated with Google Cloud:
   ```bash
   gcloud auth login
   gcloud config set project [YOUR_PROJECT_ID]
   ```

3. Run the deployment script. (Note: Modify the `PROJECT_ID` variable in `fix_pipeline.sh` before running if you are using a different project).
   ```bash
   chmod +x fix_pipeline.sh
   ./fix_pipeline.sh
   ```

## Testing the Pipeline

To verify the pipeline end-to-end, you can run the provided verification script:

```bash
chmod +x verify.sh
./verify.sh
```

Alternatively, you can manually upload a file to the GCS bucket and query the BigQuery table using the `query_bq.sh` script:

```bash
chmod +x query_bq.sh
./query_bq.sh
```
