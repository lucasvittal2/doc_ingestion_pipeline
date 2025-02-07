#!/bin/bash

#python src/doc_ingestion_pipeline/beam/pipelines/process_pdf.py \
#    --runner=DataflowRunner \
#    --project="the-bot-specialist-dev" \
#    --bucket="doc-ingestion-pipeline-dev" \
#    --input_pub_sub_topic="projects/the-bot-specialist-dev/topics/ingestion-pipeline-dev" \
#    --output_pub_sub_topic="projects/the-bot-specialist-dev/topics/doc-ingestion-output" \
#    --pub_sub_subscription="projects/the-bot-specialist-dev/subscriptions/ingestion-pipeline-dev-subscription"\
#    --template_location="gs://doc-ingestion-pipeline-dev/templates/doc_ingestion_template" \
#    --temp_location="gs://doc-ingestion-pipeline-dev/tmp"\
#    --staging_location="gs://doc-ingestion-pipeline-dev/tmp"\
#    --region="us-central1" \
#    --disk_size_gb="50"\
#    --deadletter_file="test"\
#    --max_num_workers=2\
#    --save_main_session\
#    --streaming\
#    --log_level=DEBUG\
#    --experiments=shuffle_mode=service\
#    --requirements_file requirements.txt\
#    --experiments=use_runner_v2 \
#    --sdk_container_image=us-central1-docker.pkg.dev/the-bot-specialist-dev/bot-specialist-repov1/doc-ingestion-pipeline-dev:v1\
#    --sdk_location=container

python src/doc_ingestion_pipeline/beam/pipelines/process_pdf.py \
    --runner=DataflowRunner \
    --project="the-bot-specialist-dev" \
    --bucket="doc-ingestion-pipeline-dev" \
    --input_pub_sub_topic="projects/the-bot-specialist-dev/topics/ingestion-pipeline-dev" \
    --output_pub_sub_topic="projects/the-bot-specialist-dev/topics/doc-ingestion-output" \
    --pub_sub_subscription="projects/the-bot-specialist-dev/subscriptions/ingestion-pipeline-dev-subscription" \
    --template_location="gs://doc-ingestion-pipeline-dev/templates/doc_ingestion_template" \
    --temp_location="gs://doc-ingestion-pipeline-dev/tmp" \
    --staging_location="gs://doc-ingestion-pipeline-dev/tmp" \
    --region="us-central1" \
    --max_num_workers=2 \
    --streaming \
    --experiments=shuffle_mode=service \
    --sdk_container_image=us-central1-docker.pkg.dev/the-bot-specialist-dev/bot-specialist-repov1/doc-ingestion-pipeline-dev:v1\
    --flink_version=1.18 \
    --save_main_session
