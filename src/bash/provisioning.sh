#!/bin/bash
set -e


# Collect Parameters
echo "running script with the following parameters:"
echo ""
echo "running script with the following parameters:"
echo ""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --env)
    ENV="$2"
    echo "ENV=$ENV"
    shift 2
    ;;
  --mode)
    MODE="$2"
    echo "MODE=$MODE"
    shift 2
    ;;
  --project-id)
    PROJECT_ID="$2"
    echo "PROJECT_ID=$PROJECT_ID"
    shift 2
    ;;
  --project-number)
    PROJECT_NUMBER="$2"
    echo "PROJECT_NUMBER=$PROJECT_ID"
    shift 2
    ;;
  --region)
    REGION="$2"
    echo "REGION=$REGION"
    shift 2
    ;;
  --location)
    LOCATION="$2"
    echo "LOCATION=$LOCATION"
    shift 2
    ;;
  --cloud-function-name)
    CLOUD_FUNCTION_NAME="$2"
    echo "CLOUD_FUNCTION_NAME=$CLOUD_FUNCTION_NAME"
    shift 2
    ;;
  --cron-job-name)
    CRON_JOB_NAME="$2"
    echo "CRON_JOB_NAME=$CRON_JOB_NAME"
    shift 2
    ;;
  --cron-shedule)
    CRON_SCHEDULE="$2"
    echo "CRON_SCHEDULE=$CRON_SCHEDULE"
    shift 2
    ;;
  --cron-timezone)
    CRON_TIMEZONE="$2"
    echo "CRON_TIMEZONE=$CRON_TIMEZONE"
    shift 2
    ;;
  *)
    echo "❌ Invalid option: $1"
    usage
    ;;
esac
done

create_project_gcp_resources() {
  echo ""
  echo "☁️ Starting GCP resource provisioning..."
  echo ""
  REGION=$1
  ENV=$2
  PROJECT_DIR=$(pwd)
  cd terraform/environment

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

  #Setting up alloydb
  echo "Setting up alloyDB..."
  export ALLOY_CLUSTER_ID=$(terraform output alloydb_cluster_id | awk -F'/' '{print $NF}' | sed s/\"//g)
  export ALLOY_INSTANCE_ID=$(terraform output alloydb_primary_instance_id | awk -F'/' '{print $NF}' | sed s/\"//g)
  echo "ALLOY_CLUSTER $ALLOY_CLUSTER_ID"
  gcloud alloydb instances update "$ALLOY_INSTANCE_ID" \
    --cluster="$ALLOY_CLUSTER_ID"  \
    --region="$REGION"  \
    --assign-inbound-public-ip=ASSIGN_IPV4 \
    --database-flags=password.enforce_complexity=on

  gcloud alloydb users create "user-${ENV}" \
  --password="admin-${ENV}" \
  --cluster="$ALLOY_CLUSTER_ID" \
  --region="$REGION"\
  --superuser="true"

  cd "$PROJECT_DIR"
}

deploy_cloud_function() {
    local FUNCTION_NAME="$1"
    local REGION="$2"
    local PROJECT_NUMBER="$3"
    echo ""
    echo "⚙️  Deploying cloud function '${FUNCTION_NAME}'..."

    if gcloud functions describe "$FUNCTION_NAME" --region="$REGION" &> /dev/null; then
        echo "⚠️ Warning: Cloud Function '$FUNCTION_NAME' is already deployed. Skipping deployment."
        echo ""
    else
        echo ""
        echo "⚙️  Deploying Cloud Function '$FUNCTION_NAME'..."
        gcloud functions deploy "$FUNCTION_NAME" \
            --region="$REGION" \
            --entry-point="trigger_ingestion_pipeline_http" \
            --runtime="python310" \
            --source="src/cloud_function/trigger_pdf_ingestion_dataflow_job" \
            --service-account="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
            --trigger-http \
            --allow-unauthenticated

        echo "✅ Deployment completed for '$FUNCTION_NAME'."
        echo ""
    fi
}

create_cloud_scheduler_job() {
    local JOB_NAME="$1"
    local SCHEDULE="$2"
    local TIMEZONE="$3"
    local FUNCTION_NAME="$4"
    local REGION="$5"

    echo ""
    echo "⚙️  Creating cloud scheduler job '${JOB_NAME}'..."
    if gcloud functions describe "$FUNCTION_NAME" --region="$REGION" &> /dev/null; then
        FUNCTION_URL=$(gcloud functions describe "$FUNCTION_NAME" --region="us-central1" | grep url | sed "s/url: //g")
        echo "✅ Cloud Function '$FUNCTION_NAME' found. URL: $FUNCTION_URL"
        echo ""
    else
        echo "❌ Error: Cloud Function '$FUNCTION_NAME' not found in region '$REGION'. Exiting..."
        echo ""
        return 1
    fi

    # Check if the Cloud Scheduler job already exists
    if gcloud scheduler jobs describe "$JOB_NAME" --location="$REGION" &> /dev/null; then
        echo "⚠️ Warning: Cloud Scheduler job '$JOB_NAME' already exists. Skipping creation."
        echo ""
    else
        echo "⚙️  Creating Cloud Scheduler job '$JOB_NAME'..."
        gcloud scheduler jobs create http "$JOB_NAME" \
            --schedule="$SCHEDULE" \
            --time-zone="$TIMEZONE" \
            --uri="$FUNCTION_URL" \
            --location="$REGION"

        echo ""
        echo "✅ Cloud Scheduler job '$JOB_NAME' created successfully."
        echo ""
    fi
}
## Setup Terraform generic variables
export TF_VAR_location=$LOCATION
export TF_VAR_region=$REGION
export TF_VAR_project_name=$PROJECT_ID
export TF_VAR_project_number=$PROJECT_NUMBER
export TF_VAR_env=$ENV

## Run provisioning gcp resources pipeline
if [[ "$MODE" == "CREATE" ]]; then
  create_project_gcp_resources "$REGION" "$ENV"
  deploy_cloud_function "$CLOUD_FUNCTION_NAME" "$REGION" "$PROJECT_NUMBER"
  create_cloud_scheduler_job "$CRON_JOB_NAME" "$CRON_SCHEDULE" "$CRON_TIMEZONE" "$CLOUD_FUNCTION_NAME" "$REGION"
elif [[ "$MODE" == "DESTROY" ]]; then
  echo ""
  echo "🔥 Destroying provisioned infrastructure..."
  cd terraform/environment
  terraform destroy --auto-approve
  echo "💥 Deleted all infrastructure provisioned by terraform."
  gcloud scheduler jobs delete "$CRON_JOB_NAME" --location="$REGION" --quiet
  echo "💥 Deleted Cloud Scheduler job '$CRON_JOB_NAME'."
  gcloud functions delete "$CLOUD_FUNCTION_NAME" --region="$REGION" --quiet
  echo "💥 Deleted Cloud Function '$CLOUD_FUNCTION_NAME'."
  echo "✅ Destroyed all resources successfully."
  echo ""

else
  echo "❌  You have provided an invalid mode for this script"
  echo "⚠️  Try with 'CREATE' or 'DESTROY' using the --mode parameter!"
fi
