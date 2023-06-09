terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
  zone    = var.zone
}

## cloud buckets

resource "google_storage_bucket" "static-site" {
  name          = "atip-test"
  location      = "EU"
  force_destroy = true

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket" "logs-bucket" {
  name          = "atip-deploy-logs"
  location      = "EU"
  force_destroy = true

  uniform_bucket_level_access = true
}

data "google_iam_policy" "admin" {
  binding {
    role    = "roles/storage.admin"
    members = ["serviceAccount:${var.service-account}@${var.project}.iam.gserviceaccount.com"]
  }
}

## bucket IAM

resource "google_storage_bucket_iam_policy" "policy" {
  bucket      = google_storage_bucket.logs-bucket.name
  policy_data = data.google_iam_policy.admin.policy_data
}

# Create a secret containing the personal access token and grant permissions to the Service Agent 
resource "google_secret_manager_secret" "github_token_secret" {
  project   = var.project
  secret_id = var.secret_id

  replication {
    automatic = true
  }
}

data "google_iam_policy" "serviceagent_secretAccessor" {
  binding {
    role    = "roles/secretmanager.secretAccessor"
    members = ["serviceAccount:${var.service-account}@${var.project}.iam.gserviceaccount.com"]
  }
}


resource "google_secret_manager_secret_version" "github_token_secret_version" {
  secret      = google_secret_manager_secret.github_token_secret.id
  secret_data = file(var.secret_file)
}


resource "google_secret_manager_secret_iam_policy" "policy" {
  project     = google_secret_manager_secret.github_token_secret.project
  secret_id   = google_secret_manager_secret.github_token_secret.secret_id
  policy_data = data.google_iam_policy.serviceagent_secretAccessor.policy_data
}



## cloud build

resource "google_cloudbuildv2_connection" "my-connection" {
  provider = google-beta
  location = var.region
  name     = "my-connection"

  github_config {
    app_installation_id = 38443484
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github_token_secret_version.id
    }
  }
  depends_on = [google_secret_manager_secret_iam_policy.policy]
}

resource "google_cloudbuildv2_repository" "my-repository" {
  provider          = google-beta
  name              = "atip-fork"
  parent_connection = google_cloudbuildv2_connection.my-connection.id
  remote_uri        = "https://github.com/sparrow0hawk/atip.git"
}

resource "google_cloudbuild_trigger" "repo-trigger" {
  provider = google-beta
  location = var.region

  repository_event_config {
    repository = google_cloudbuildv2_repository.my-repository.id
    push {
      branch = "rel-.*"
    }
  }

  filename = "cloudbuild.yaml"
}
