PROJECT_ID="test-deploy-atip2"
PROJECT_NAME="Test deploy ATIP"

# create project in gcp
gcloud projects create $PROJECT_ID  --name="$PROJECT_NAME"

# set current project with gcloud as this project
gcloud config set project $PROJECT_ID

# find out BILLING_ACCOUNT_ID from
# gcloud beta billing accounts list
gcloud beta billing projects link $PROJECT_ID \
 --billing-account $BILLING_ACCOUNT_ID

gcloud services enable \
    storage.googleapis.com \
    secretmanager.googleapis.com \
    iam.googleapis.com \
    cloudbuild.googleapis.com \
    cloudresourcemanager.googleapis.com

SERVICE_ACCT=deploy-atiper

gcloud iam service-accounts create $SERVICE_ACCT \
 --display-name "Deploy ATIPer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCT@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/owner"

gcloud iam service-accounts keys create .credentials.json \
    --iam-account=$SERVICE_ACCT@$PROJECT_ID.iam.gserviceaccount.com
