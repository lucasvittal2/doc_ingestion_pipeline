#!/bin/bash

set -e

create_gcs_pipeline_bucket() {
  local BUCKET_NAME=$1
  local PROJECT_ID=$2

  if gcloud storage buckets list --project="$PROJECT_ID" --format="value(name)" | grep -q "^$BUCKET_NAME$"; then
    echo "Bucket '$BUCKET_NAME' already exist, no action is needed."
  else
    echo ""
    echo "Creating bucket '$BUCKET_NAME'..."
    echo ""
    gcloud storage buckets create "gs://$BUCKET_NAME" \
      --project="$PROJECT_ID" \
      --location="US" \
      --uniform-bucket-level-access
  fi
}

build_container() {
  local REGISTRY_URL=$1
  local BEAM_IMAGE="apache/beam_python3.11_sdk"
  local BEAM_VERSION="2.59.0"

  # Validate input parameters
  if [[ -z "$REGISTRY_URL"  ]]; then
    echo ""
    echo "❌ Error: Missing parameters! Usage: build_container <$REGISTRY_URL>"
    echo ""
    return 1
  fi

  echo ""
  echo "🚀 Starting container build: $REGISTRY_URL"
  echo ""
  # Run Docker build
  docker build \
    --build-arg BEAM_IMAGE="$BEAM_IMAGE" \
    --build-arg BEAM_VERSION="$BEAM_VERSION" \
    -t "$REGISTRY_URL" .

  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo ""
    echo "❌ Error: Docker build failed! Check logs in $LOG_FILE."
    echo ""
    return 1
  fi

  echo ""
  echo "✅ Container built successfully: $REGISTRY_URL"
  echo ""
  return 0
}

create_artifact_repo() {
  REPOSITORY_NAME=$1
  PROJECT_ID=$2


  echo ""
  echo "Creating repository ${REPOSITORY_NAME}..."
  echo ""

  # Verifica se o repositório já existe
  if ! gcloud artifacts repositories list --location=us-central1 --project="$PROJECT_ID" | grep -q "$REPOSITORY_NAME"; then
    # Cria o repositório se não existir
    gcloud artifacts repositories create "$REPOSITORY_NAME" \
        --repository-format=docker \
        --location="us-central1" \
        --description="Repository to store bot specialist container image." \
        --project="$PROJECT_ID"

    created_artifact_repo=$?

    # Verifica se o repositório foi criado com sucesso
    if [ $created_artifact_repo -eq 0 ]; then
      echo "✅ Repository ${REPOSITORY_NAME} created successfully!"
    else
      echo ""
      echo "❌ Error creating repository ${REPOSITORY_NAME}."
      echo ""
      exit 1
    fi
  else
    echo "⚠️ The repository ${REPOSITORY_NAME} already exists! Not created this repository again."
  fi
}

# shellcheck disable=SC2120
push_container_gcp(){
  REGISTRY_URL="$1"

  # Autentica no Google Artifact Registry, se necessário
  if ! gcloud auth configure-docker --quiet; then
    echo ""
    echo "❌ Erro ao configurar autenticação do Docker com o Google Cloud."
    echo ""
    return 1
  fi
  echo""
  echo "🚀 Pushing image to $REGISTRY_URL..."
  echo ""
  if docker push "$REGISTRY_URL"; then
    echo ""
    echo "🐋 Image pushed successfully to $REGISTRY_URL."
    echo ""
  else
    echo ""
    echo "❌ Failed to push image to $REGISTRY_URL. Check logs above ! "
    echo ""
    exit 1
  fi
}

create_pipeline_template() {
  PROJECT_ID=$1
  PROJECT_NUMBER=$2
  REGION=$3
  REPOSITORY_NAME=$4
  ENV=$5

  if [[ -z "$PROJECT_ID" || -z "$PROJECT_NUMBER" || -z "$REGION" || -z "$REPOSITORY_NAME" || -z "$ENV" ]]; then
        echo "❌ Error: Missing parameters!"
        echo "Usage: create_pipeline_template <PROJECT_ID> <PROJECT_NUMBER> <REGION> <REPOSITORY_NAME> <ENV>"
        return 1
  fi
  echo ""
  echo "⚙️ Starting pipeline creation for project: $PROJECT_ID (Env: $ENV)"
  echo ""

  # Run the pipeline creation command
  python src/doc_ingestion_pipeline/beam/pipelines/process_pdf.py \
    --runner=DataflowRunner \
    --project="$PROJECT_ID" \
    --bucket="doc-ingestion-pipeline-${ENV}-${PROJECT_NUMBER}" \
    --input_pub_sub_topic="projects/${PROJECT_ID}/topics/ingestion-pipeline-${ENV}" \
    --output_pub_sub_topic="projects/${PROJECT_ID}/topics/doc-ingestion-output" \
    --pub_sub_subscription="projects/${PROJECT_ID}/subscriptions/ingestion-pipeline-${ENV}-subscription" \
    --template_location="gs://doc-ingestion-pipeline-${ENV}-${PROJECT_NUMBER}/templates/doc_ingestion_template" \
    --temp_location="gs://doc-ingestion-pipeline-${ENV}-${PROJECT_NUMBER}/tmp" \
    --staging_location="gs://doc-ingestion-pipeline-${ENV}-${PROJECT_NUMBER}/staging" \
    --region="$REGION" \
    --max_num_workers=2 \
    --streaming \
    --experiments=shuffle_mode=service \
    --sdk_container_image="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/doc-ingestion-pipeline-${ENV}:v1" \
    --flink_version=1.18 \
    --save_main_session

  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo ""
    echo "⚠️  Pipeline creation failed! Check logs in $LOG_FILE."
    echo ""
    return 1
  fi

  echo ""
  echo "✅  Pipeline successfully created for environment: $ENV!"
  echo ""
  return 0
}

create_project_gcp_resources() {
  echo ""
  echo "☁️ Starting GCP resource provisioning..."
  echo ""

  PROJECT_DIR=$(pwd)
  cd terraform/environments/dev

  # Initialize, plan, and apply Terraform
  terraform init && terraform plan && terraform apply --auto-approve
  if [[ $? -ne 0 ]]; then
    echo "❌ Error: Provisioning GCP resources failed! Check the logs above."
    cd "$PROJECT_DIR"
    return 1
  fi

  echo ""
  echo "✅ GCP resources provisioned successfully!"
  echo ""

  cd "$PROJECT_DIR"
}

# Collect Parameters
echo "running script with the following parameters:"
echo ""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --env)
    ENV="$2"
    echo "ENV=$ENV"
    shift 2
    ;;
  --pipeline-bucket)
    PIPELINE_BUCKET="$2"
    echo "ENV=$ENV"
    shift 2
    ;;
  --registry-repo-name)
    REPOSITORY_NAME="$2"
    echo "REPOSITORY_NAME=$REPOSITORY_NAME"
    shift 2
    ;;
  --container-image)
    CONTAINER_IMAGE="$2"
    echo "CONTAINER_IMAGE=$CONTAINER_IMAGE"
    shift 2
    ;;
  --project-id)
    PROJECT_ID="$2"
    echo "PROJECT_ID=$PROJECT_ID"
    shift 2
    ;;

  --project-number)
    PROJECT_NUMBER="$2"
    echo "PROJECT_ID=$PROJECT_ID"
    shift 2
    ;;
  --region)
    REGION="$2"
    echo "PROJECT_ID=$PROJECT_ID"
    shift 2
    ;;
  *)
    echo "❌ Invalid option: $1"
    usage
    ;;
esac
done

# Main Execution
REGISTRY_URL="us-central1-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${CONTAINER_IMAGE}"
create_gcs_pipeline_bucket "$PIPELINE_BUCKET" "$PROJECT_ID"
build_container "$REGISTRY_URL"
create_artifact_repo "$REPOSITORY_NAME" "$PROJECT_ID"
push_container_gcp "$REGISTRY_URL"
create_pipeline_template "$PROJECT_ID" "$PROJECT_NUMBER" "$REGION" "$REPOSITORY_NAME" "$ENV"
create_project_gcp_resources
