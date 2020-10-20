#!/bin/bash
# Instantiate a deployed Dataproc workflow using gcloud
# param $1 - cluster workers count

gcloud dataproc workflow-templates instantiate ${WORKFLOW} \
--region=${REGION} \
--parameters=CLUSTER_WORKERS_COUNT=$1,MAIN_PYTHON_FILE=${SPARK_JOB_PATH}spark_job.py,INPUT_TABLE=${INPUT_TABLE},OUTPUT_TABLE=${OUTPUT_TABLE},TEMP_GCS_BUCKET=${BUCKET}
