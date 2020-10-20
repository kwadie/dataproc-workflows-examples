# Copyright (C) 2020 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

from pyspark.sql import SparkSession
import sys

if __name__ == '__main__':

    input_table = sys.argv[1]
    output_table = sys.argv[2]
    temp_gcs_bucket = sys.argv[3]


    spark = SparkSession.builder \
        .appName('BigQuery Storage & Spark DataFrames') \
        .getOrCreate()

    df_wiki_pageviews = spark.read \
        .format("bigquery") \
        .option("table", input_table) \
        .option("filter", "datehour >= '2020-03-01' AND datehour < '2020-03-02'") \
        .load()

    df_wiki_en = df_wiki_pageviews \
        .select("title", "wiki", "views", "datehour") \
        .where("views > 10 AND wiki in ('en', 'en.m')")

    df_wiki_en.write \
        .format('bigquery') \
        .option('temporaryGcsBucket', temp_gcs_bucket) \
        .option('table', output_table) \
        .option('createDisposition', 'CREATE_NEVER') \
        .mode('overwrite') \
        .save()
