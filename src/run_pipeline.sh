#!/bin/bash

python src/doc_ingestion_pipeline/beam/pipelines/process_pdf.py \
    --project="bot-especialist-dev" \
    --bucket="doc-ingestion-pipeline-dev" \
    --input_pub_sub_topic="projects/bot-especialist-dev/topics/ingestion-pipeline-dev" \
    --output_pub_sub_topic="projects/bot-especialist-dev/topics/doc-ingestion-output" \
    --pub_sub_subscription="projects/bot-especialist-dev/subscriptions/ingestion-pipeline-dev-subscription"\
    --template_location="gs://doc-ingestion-pipeline-dev/templates/doc_ingestion_template" \
    --temp_location="gs://doc-ingestion-pipeline-dev/tmp"\
    --staging_location="gs://doc-ingestion-pipeline-dev/tmp"\
    --region="us-east4" \
    --disk_size_gb="50"\
    --deadletter_file="test"\
    --max_num_workers=2\
    --save_main_session\
    --streaming
