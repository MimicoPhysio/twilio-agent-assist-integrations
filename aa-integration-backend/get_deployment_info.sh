#!/bin/bash
#
# A script to retrieve information about your deployed Agent Assist backend.
#
# Instructions:
# 1. Make sure you are authenticated with gcloud (`gcloud auth login`).
# 2. Make sure you have `jq` installed (e.g., `sudo apt-get install jq`).
# 3. Set the GCP_PROJECT_ID and SERVICE_REGION variables below.
# 4. Run the script: `sh get_deployment_info.sh`

set -e

# --- Configuration ---
GCP_PROJECT_ID=$(gcloud config get-value project)
SERVICE_REGION="us-central1"
# The names of your services, as defined in deploy.sh
CONNECTOR_SERVICE_NAME="ui-connector"
INTERCEPTOR_SERVICE_NAME="cloud-pubsub-interceptor"
REDIS_INSTANCE_ID="aa-integration-redis"
JWT_SECRET_NAME="agent-assist-jwt-secret" # Updated based on your list
VPC_CONNECTOR_NAME="aa-integration-vpc" # Only if you used a VPC connector

# --- Helper function for printing headers ---
print_header() {
    echo ""
    echo "==============================================================================="
    echo " $1"
    echo "==============================================================================="
}

# --- Project and Account Info ---
print_header "Project and Account Information"
echo "Current Project: $(gcloud config get-value project)"
echo "Current Admin Account: $(gcloud config get-value account)"

# --- Cloud Run Services ---
print_header "Cloud Run Services"
echo "Listing services in region $SERVICE_REGION..."
gcloud run services list --region $SERVICE_REGION --format="table(NAME, URL, REGION)"

print_header "UI Connector ($CONNECTOR_SERVICE_NAME) Details"
if ! gcloud run services describe $CONNECTOR_SERVICE_NAME --region $SERVICE_REGION --format=json >/dev/null 2>&1; then
    echo "Cloud Run service '$CONNECTOR_SERVICE_NAME' not found in region '$SERVICE_REGION'."
else
    UI_CONNECTOR_INFO=$(gcloud run services describe $CONNECTOR_SERVICE_NAME --region $SERVICE_REGION --format=json)
    echo "URL: $(echo $UI_CONNECTOR_INFO | jq -r .status.url)"
    echo "Service Account: $(echo $UI_CONNECTOR_INFO | jq -r .spec.template.spec.serviceAccountName)"
    echo "Environment Variables:"
    echo $UI_CONNECTOR_INFO | jq -r '.spec.template.spec.containers[0].env[]? | "\(.name)=\(.value)"' | sort
fi

print_header "Pub/Sub Interceptor ($INTERCEPTOR_SERVICE_NAME) Details"
if ! gcloud run services describe $INTERCEPTOR_SERVICE_NAME --region $SERVICE_REGION --format=json >/dev/null 2>&1; then
    echo "Cloud Run service '$INTERCEPTOR_SERVICE_NAME' not found in region '$SERVICE_REGION'."
else
    INTERCEPTOR_INFO=$(gcloud run services describe $INTERCEPTOR_SERVICE_NAME --region $SERVICE_REGION --format=json)
    echo "URL: $(echo $INTERCEPTOR_INFO | jq -r .status.url)"
    echo "Service Account: $(echo $INTERCEPTOR_INFO | jq -r .spec.template.spec.serviceAccountName)"
    echo "Environment Variables:"
    echo $INTERCEPTOR_INFO | jq -r '.spec.template.spec.containers[0].env[]? | "\(.name)=\(.value)"' | sort
fi

# --- Memorystore for Redis ---
print_header "Memorystore for Redis"
if ! gcloud redis instances describe $REDIS_INSTANCE_ID --region $SERVICE_REGION --format=json >/dev/null 2>&1; then
    echo "Redis instance '$REDIS_INSTANCE_ID' not found in region '$SERVICE_REGION'."
else
    REDIS_INFO=$(gcloud redis instances describe $REDIS_INSTANCE_ID --region $SERVICE_REGION --format=json)
    echo "Instance ID: $REDIS_INSTANCE_ID"
    echo "Host: $(echo $REDIS_INFO | jq -r .host)"
    echo "Port: $(echo $REDIS_INFO | jq -r .port)"
    echo "VPC Network: $(echo $REDIS_INFO | jq -r .authorizedNetwork)"
fi

# --- VPC Connector (if used) ---
if gcloud compute networks vpc-access connectors describe $VPC_CONNECTOR_NAME --region $SERVICE_REGION >/dev/null 2>&1; then
    print_header "Serverless VPC Access Connector"
    VPC_INFO=$(gcloud compute networks vpc-access connectors describe $VPC_CONNECTOR_NAME --region $SERVICE_REGION --format=json)
    echo "Connector Name: $VPC_CONNECTOR_NAME"
    echo "Network: $(echo $VPC_INFO | jq -r .network)"
    echo "IP Range: $(echo $VPC_INFO | jq -r .ipCidrRange)"
fi

# --- Pub/Sub Topics and Subscriptions ---
print_header "Pub/Sub Topics & Subscriptions"
gcloud pubsub subscriptions list --format="table(name.segment(-1):label=SUBSCRIPTION_ID, topic.segment(-1):label=TOPIC, pushConfig.pushEndpoint:label=PUSH_ENDPOINT)"

# --- Secret Manager ---
print_header "Secret Manager"
gcloud secrets list --filter="name~'$JWT_SECRET_NAME'" --format="table(name, createTime)"

# --- IAM Service Accounts ---
print_header "IAM Service Accounts"
gcloud iam service-accounts list --filter="displayName~'Agent Assist integration' OR displayName~'Cloud Run Pub/Sub Invoker'" --format="table(displayName, email)"

echo ""
echo "Script finished."