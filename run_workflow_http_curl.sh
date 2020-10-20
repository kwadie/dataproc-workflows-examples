#!/bin/bash

# Use this command to debug the HTTP request and to have descriptive errors. When the same logic fails in
# Cloud Scheduler it doesn't show full error description.

# Get authentication token and strip it from carriage return
export AUTH_TOKEN=$(docker run -it gcr.io/oauth2l/oauth2l header cloud-platform | tr -d '\r')

curl -X POST \
"https://dataproc.googleapis.com/v1/projects/${PROJECT}/regions/${REGION}/workflowTemplates/${WORKFLOW}:instantiate?alt=json" \
-H "${AUTH_TOKEN}" \
-H "Content-Type: application/json" \
-d '{
  "parameters": {
    "CLUSTER_WORKERS_COUNT" : "2",
    "MAIN_PYTHON_FILE": "'"${SPARK_JOB_PATH}spark_job.py"'",
    "INPUT_TABLE": "'"${INPUT_TABLE}"'",
    "OUTPUT_TABLE": "'"${OUTPUT_TABLE}"'",
    "TEMP_GCS_BUCKET": "'"${BUCKET}"'"
  }
}'