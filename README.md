# Dataproc workflows examples

## Copyright
Copyright (C) 2020 Google Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not
use this file except in compliance with the License. You may obtain a copy of
the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations under
the License.

## Overview
This is a proof of concept to facilitate Hadoop/Spark workloads migrations to GCP. The POC covers the following:
* Usage of [spark-bigquery-connector](https://github.com/GoogleCloudDataproc/spark-bigquery-connector) to read and write from/to BigQuery.
* Usage of [Dataproc workflow templates](https://cloud.google.com/dataproc/docs/concepts/workflows/overview) to run jobs on ephemeral clusters
* Usage of [Cloud Scheduler](https://cloud.google.com/scheduler/docs) to trigger the these workflows on regular basis (i.e. CRON)
* Usage of `gcloud dataproc workflow-templates` and `curl` commands to trigger these workflows on demand.

The POC could be configured to use your own job(s) and to estimate GCP cost for such a workload over a period of time. (hint: use resource labels as defined in the workflow template YAML files to track cost) 

## Option 1: Spark on Dataproc

### Components

#### PySpark Job
A sample job to read from public BigQuery wikipedia dataset `bigquery-public-data.wikipedia.pageviews_2020`, 
apply filters and write results to an daily-partitioned BigQuery table . The job is using 
[spark-bigquery-connector](https://github.com/GoogleCloudDataproc/spark-bigquery-connector) to read and write from/to BigQuery.

The job expects the following parameters:
1. input_table: BigQuery input table to read from
2. output_table: BigQuery input table to write to
3. temp_gcs_bucket: An existing GCS bucket name that the spark-bigquery-connector uses to stage temp files

#### BigQuery
Input table `bigquery-public-data.wikipedia.pageviews_2020` is in a public dataset while `<project>.<dataset>.output` is created manually as explained in the ["Usage" section](#usage)

#### Workflow Templates

[Dataproc workflow templates](https://cloud.google.com/dataproc/docs/concepts/workflows/overview) provide the ability
to define a job graph of multiple steps and their execution order/dependency. These steps/jobs could run on either:
* **A cluster selector:** an existing Dataproc cluster
* **A managed cluster:** an ephemeral cluster that the workflow creates and terminates after the steps have completed

Workflow templates could be defined via `gcloud dataproc workflow-templates` commands and/or via YAML files. YAML files
are generally easier to keep track of and they allow [parametrization](https://cloud.google.com/dataproc/docs/concepts/workflows/workflow-parameters).

In this POC we provide multiple examples of workflow templates defined in YAML files:

1. [workflow_cluster_selector.yaml](workflow_cluster_selector.yaml): uses a cluster selector to determine which
   existing cluster to run the workflow on. It expects the cluster name as one of it's parameters.
   
2. [workflow_managed_cluster.yaml](workflow_managed_cluster.yaml): creates an ephemeral cluster according to
   defined specs. It expects the number of primary worker nodes as one of it's parameters.
   
3. [workflow_managed_cluster_preemptible_vm.yaml](workflow_managed_cluster_preemptible_vm.yaml): same as 
   [workflow_managed_cluster.yaml](workflow_managed_cluster.yaml), in addition, the cluster utilizes 
   [Preemptible VMs](https://cloud.google.com/dataproc/docs/concepts/compute/preemptible-vms) 
   for cost reduction with long-running batch jobs.
   
4. [workflow_managed_cluster_preemptible_vm_efm.yaml](workflow_managed_cluster_preemptible_vm_efm.yaml): same as 
   [workflow_managed_cluster_preemptible_vm.yaml](workflow_managed_cluster_preemptible_vm.yaml), in addition, 
   the cluster utilizes [Enhanced Flexibility Mode for Spark jobs](https://cloud.google.com/dataproc/docs/concepts/configuring-clusters/flex)
   to minimize job progress delays caused by the removal of nodes (e.g Preemptible VMs) from a running cluster.
  
  
 ##### Defining YAML Workflow Templates
  
To find out the YAML elements to use, a typical workflow would be
 * Defining a workflow template component via `gcloud dataproc workflow-templates` [commands](https://cloud.google.com/sdk/gcloud/reference/dataproc/workflow-templates)
 * Exporting the workflow template as a YAML file via `gcloud dataproc workflow-templates export`
 * Inspecting and editing the YAML file locally
 * Updating the workflow template by importing the YAML file via `gcloud dataproc workflow-templates import`
  
For more details about the export/import flow please refer to this [article](https://cloud.google.com/dataproc/docs/concepts/workflows/using-yamls#import_and_export_a_workflow_template_yaml_file).
   
#### Cloud Scheduler

In this POC we use a Cloud Scheduler job to trigger the Dataproc workflow based on a cron expression (or on-demand) 
via an [HTTP endpoint](https://cloud.google.com/sdk/gcloud/reference/scheduler/jobs/create/http). 
The workflow parameters are passed as a JSON payload as defined in [deploy.sh](deploy.sh)

##### Debugging HTTP endpoints with curl

During the development of a Cloud Scheduler job, sometimes the log messages won't contain detailed information
about the HTTP errors returned by the endpoint. For this, using `curl` and `curl -v` could be helpful
in debugging the endpoint and the request payload. [run_workflow_http_curl.sh](run_workflow_http_curl.sh) contains an example of such command.

### Usage

In a cloud shell or terminal run the following commands 

* Configure environment variables
```
export PROJECT=<project name>
export REGION=<gcp region>

export BUCKET=<bucket name without gs:// prefix>
export SPARK_JOB_PATH=gs://${BUCKET}/jobs/
export WORKFLOW=<dataproc workflow template name>

export BQ_DATASET=<bigquery dataset name>
export OUTPUT_TABLE_NAME=<bigquery output table name without project or dataset>
export INPUT_TABLE=<bigquery input table in the format project.dataset.table>
export OUTPUT_TABLE=${PROJECT}.${BQ_DATASET}.${OUTPUT_TABLE_NAME}

export SCHEDULER=<cloud scheduler job name>
export SCHEDULER_SERVICE_ACCOUNT=<service account email to execute workflows with dataproc.workflowTemplates.instantiate permission>

```

* Configure gcloud
```
gcloud config set project ${PROJECT}
 ```

* Create BigQuery Dataset
```
bq mk --location=$REGION ${BQ_DATASET}
 ```
 
* Create an empty BigQuery output table
 ```
bq mk --table \
--time_partitioning_field datehour \
--time_partitioning_type DAY \
${PROJECT}:${BQ_DATASET}.${OUTPUT_TABLE_NAME} \
bigquery_table_schema_output.json
```

* Deploy resources to GCP

```
# . deploy.sh <create|update> <workflow.yaml>
# For example

. deploy.sh create workflow_managed_cluster.yaml
```

* Trigger the Cloud Scheduler job
```
. run_workflow_scheduler.sh
```

* In Cloud Scheduler console, confirm the last execution status of the job

* Other options to execute the workflow directly without cloud scheduler are [run_workflow_gcloud.sh](run_workflow_gcloud.sh) and [run_workflow_http_curl.sh](run_workflow_http_curl.sh)



### Limitations
* The beta version of [spark-bigquery-connector](https://github.com/GoogleCloudDataproc/spark-bigquery-connector) 
  supports writing to partitioned tables that are on DAY level only. Further support of hourly partitioned tables 
  (and others) might be expected in the GA version. 
* Using [argsparse](https://docs.python.org/3/library/argparse.html) or similar libs for argument parsing 
  gets complicated when passing the PySpark job arguments from the Dataproc workflow template. Dataproc workflow 
  templates pass the parameter values directly to the job, while argparser expects key-value pairs of 
  {--parameter_name=parameter_value}
  
### Possible Extensions

#### Experiment with several Dataproc specs
* Auto-scaling and Auto-scaling policies for batch jobs
* Workflows that group short jobs in one managed cluster
* For large jobs, Preemptible VMs (for cost reduction) and Enhanced Flexibility Mode for spark jobs (for better performance with preemptible VMs)
 

#### Other Workflow Scheduling solutions

One could also use cloud functions and/or Cloud Composer to orchestrate Dataproc workflow templates and Dataproc jobs in
in general. Check out this [article](https://cloud.google.com/dataproc/docs/concepts/workflows/workflow-schedule-solutions) for more details.

#### Logging Tips

* For ephemeral clusters, If you expect your clusters to be torn down, you need to persist logging information. 
  Stackdriver will capture the driver program’s stdout. 
  However, some organizations rely on the YARN UI for application monitoring and debugging. 
  The YARN UI is really just a window on logs we can aggregate to Cloud Storage. 
  With logs on Cloud Storage, we can use a long running single-node Cloud Dataproc cluster to act as the 
  MapReduce and Spark Job History Servers for many ephemeral and/or long-running clusters.

## Option 2: Dataproc on GKE
This feature allows you to submit Spark jobs to a running Google Kubernetes Engine cluster from the Dataproc Jobs API.

Use this feature to:

* Deploy unified resource management
* Isolate Spark jobs to accelerate the analytics life cycle

This requires:
* A single node (master) Dataproc cluster to submit jobs to
* A GKE Cluster to run jobs at (as worker nodes via GKE workloads)

### Limitations
* Beta version is not supported in the workflow templates API for managed clusters. Can't create a managed Dataproc cluster with the `--gke-cluster=<GKE_CLUSTER>` option from workflow templates. However, a cluster selector should be possible.

### Resources
* [Cloud Dataproc Spark Jobs on GKE: How to get started](https://cloud.google.com/blog/products/data-analytics/alpha-access-to-cloud-dataproc-jobs-on-gke)
* [Dataproc on Google Kubernetes Engine](https://cloud.google.com/dataproc/docs/concepts/jobs/dataproc-gke)

TODO: Phase 2