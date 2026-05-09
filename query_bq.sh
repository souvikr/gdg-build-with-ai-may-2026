#!/bin/bash
set -e

if [ -f .env ]; then
  source .env
else
  echo "Error: .env file not found."
  exit 1
fi
DATASET="pipeline_data"
TABLE="processed_docs"

echo "=== Table Metadata (Schema) ==="
# Using bq.cmd for Windows Git Bash compatibility
bq.cmd show "${PROJECT_ID}:${DATASET}.${TABLE}"

echo ""
echo "=== Recent Table Rows ==="
# Piping the query to avoid quote parsing issues in Git Bash
echo "SELECT * FROM \`${PROJECT_ID}.${DATASET}.${TABLE}\` ORDER BY upload_date DESC LIMIT 20" | bq.cmd query --use_legacy_sql=false
