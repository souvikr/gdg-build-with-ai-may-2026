#!/bin/bash
set -e

PROJECT_ID="gdg-mauritius-build-with-ai"
DATASET="pipeline_data"
TABLE="processed_docs"

echo "=== Table Metadata (Schema) ==="
# Using bq.cmd for Windows Git Bash compatibility
bq.cmd show "${PROJECT_ID}:${DATASET}.${TABLE}"

echo ""
echo "=== Recent Table Rows ==="
# Piping the query to avoid quote parsing issues in Git Bash
echo "SELECT * FROM \`${PROJECT_ID}.${DATASET}.${TABLE}\` ORDER BY processed_date DESC LIMIT 20" | bq.cmd query --use_legacy_sql=false
