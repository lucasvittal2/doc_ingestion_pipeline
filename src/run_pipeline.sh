#!/bin/bash

python src/doc_ingestion_pipeline/beam/pipelines/process_pdf.py \
    --runner=DataflowRunner \
    --project="bot-especialist-dev" \
    --bucket="doc-ingestion-pipeline-dev" \
    --pub_sub_topic="projects/bot-especialist-dev/topics/ingestion-pipeline-dev" \
    --template_location="gs://doc-ingestion-pipeline-dev/templates/doc_ingestion_template" \
    --temp_location="gs://doc-ingestion-pipeline-dev/tmp" \
    --region="us-central1" \
    --deadletter_file="test"
    --max_num_workers=2
