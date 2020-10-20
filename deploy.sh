#!/bin/bash
# param $1 - create | update
# param $2 - YAML workflow definition file

if [ "$1" != "create" ] && [ "$1" != "update" ]; then
  echo "$1"
  echo "deployment script expects one of these parameters in $1 [create, update]"
  exit 1
fi

# Deploy the job to GCS.
gsutil cp spark_job.py ${SPARK_JOB_PATH}

# Deploy the workflow template to Dataproc based on a given YAML file.
gcloud dataproc workflow-templates import ${WORKFLOW} \
  --region=${REGION} \
  --source=$2

# Deploy a Cloud Scheduler job based on JSON payload that includes the workflow parameters.
# oauth-service-account-email uses a service account with dataproc.workflowTemplates.instantiate permission

gcloud scheduler jobs $1 http ${SCHEDULER} \
  --http-method=post \
  --uri="https://dataproc.googleapis.com/v1/projects/${PROJECT}/regions/${REGION}/workflowTemplates/${WORKFLOW}:instantiate?alt=json" \
  --schedule="0 * * * *" \
  --time-zone="Europe/Berlin" \
  --oauth-service-account-email=${SCHEDULER_SERVICE_ACCOUNT} \
  --message-body='{
  "parameters": {
    "CLUSTER_WORKERS_COUNT" : "2",
    "MAIN_PYTHON_FILE": "'"${SPARK_JOB_PATH}spark_job.py"'",
    "INPUT_TABLE": "'"${INPUT_TABLE}"'",
    "OUTPUT_TABLE": "'"${OUTPUT_TABLE}"'",
    "TEMP_GCS_BUCKET": "'"${BUCKET}"'"
  }
}'
