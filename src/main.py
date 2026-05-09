import base64
import json
import os
import datetime
from flask import Flask, request
from google.cloud import bigquery

app = Flask(__name__)

# Initialize BigQuery client
# We rely on the Cloud Run default service account for authentication
try:
    bq_client = bigquery.Client()
except Exception as e:
    print(f"Warning: Could not initialize BigQuery client (this is expected during local build): {e}")
    bq_client = None

# BigQuery details from environment variables
BQ_DATASET = os.environ.get('BQ_DATASET', 'doc_processing')
BQ_TABLE = os.environ.get('BQ_TABLE', 'metadata')
PROJECT_ID = os.environ.get('PROJECT_ID', 'gdg-mauritius-build-with-ai')

@app.route('/', methods=['POST'])
def process_message():
    """Receive and parse Pub/Sub messages."""
    envelope = request.get_json()
    if not envelope:
        msg = 'no Pub/Sub message received'
        print(f'error: {msg}')
        return f'Bad Request: {msg}', 400

    if not isinstance(envelope, dict) or 'message' not in envelope:
        msg = 'invalid Pub/Sub message format'
        print(f'error: {msg}')
        return f'Bad Request: {msg}', 400

    pubsub_message = envelope['message']

    name = 'World'
    if isinstance(pubsub_message, dict) and 'data' in pubsub_message:
        # Decode the base64-encoded message data
        try:
            data = base64.b64decode(pubsub_message['data']).decode('utf-8')
            event_data = json.loads(data)
            
            # Extract details from the GCS event
            bucket_name = event_data.get('bucket')
            file_name = event_data.get('name')
            file_size = event_data.get('size')
            content_type = event_data.get('contentType')
            
            print(f"Processing file: gs://{bucket_name}/{file_name}")
            
            # Simulate OCR / Document Processing
            word_count = len(file_name) * 10 + 42 # Dummy logic
            tags = [content_type, 'processed']
            if 'pdf' in file_name.lower():
                tags.append('document')
            elif 'jpg' in file_name.lower() or 'png' in file_name.lower():
                tags.append('image')
                
            metadata = {
                "filename": file_name,
                "upload_date": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "tags": json.dumps(tags),
                "word_count": word_count
            }
            
            # Insert into BigQuery
            if bq_client:
                table_id = f"{PROJECT_ID}.{BQ_DATASET}.{BQ_TABLE}"
                errors = bq_client.insert_rows_json(table_id, [metadata])
                if errors:
                    print(f"Encountered errors while inserting rows: {errors}")
                    return f"Error inserting into BigQuery", 500
                else:
                    print(f"Successfully processed {file_name}")
            else:
                print(f"Dry run (No BQ Client): Metadata would be {metadata}")

        except Exception as e:
            print(f"Error processing message: {e}")
            return f"Error: {e}", 500

    return ('', 204)

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
