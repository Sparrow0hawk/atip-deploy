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

# data

data "google_project" "project" {
  project_id = var.project
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
    role = "roles/storage.admin"
    members = [
      "serviceAccount:${var.service-account}@${var.project}.iam.gserviceaccount.com",
      "projectOwner:${var.project}"
    ]
  }
}

data "google_iam_policy" "static-site" {
  binding {
    role = "roles/storage.admin"
    members = [
      "serviceAccount:${var.service-account}@${var.project}.iam.gserviceaccount.com",
      "projectOwner:${var.project}"
    ]
  }
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "allUsers",
    ]
  }
}

## bucket IAM

resource "google_storage_bucket_iam_policy" "logs-bucket-admin-policy" {
  bucket      = google_storage_bucket.logs-bucket.name
  policy_data = data.google_iam_policy.admin.policy_data
}

resource "google_storage_bucket_iam_policy" "static-site-policy" {
  bucket      = google_storage_bucket.static-site.name
  policy_data = data.google_iam_policy.static-site.policy_data
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
    members = ["serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
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
  remote_uri        = "https://github.com/Sparrow0hawk/atip.git"
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

  build {
    step {
      # Step 1: Pull the repository from GitHub
      name = "gcr.io/cloud-builders/git"
      args = ["clone", "https://github.com/Sparrow0hawk/atip.git", "source"]
      id   = "checkout"
    }
    # Step 2: Install deps and run playwright tests
    step {
      name       = "ghcr.io/sparrow0hawk/rust-wasm-packbase:main"
      entrypoint = "npm"
      args       = ["run", "wasm-release"]
      dir        = "source"
      id         = "wasm"
      wait_for   = ["checkout"]
    }

    step {
      name     = "mcr.microsoft.com/playwright:v1.35.0-jammy"
      script   = "npm ci && npx playwright install --with-deps && npm run test"
      dir      = "source"
      id       = "playwright"
      wait_for = ["wasm"]
      timeout  = 420
    }

    # Step 4: Build the project
    step {
      name       = "node:18"
      entrypoint = "npm"
      args       = ["run", "build"]
      dir        = "source"
      id         = "build"
      wait_for   = ["playwright"]
    }
    # Step 5: Upload the "dist" folder to Cloud Storage
    step {
      name     = "gcr.io/cloud-builders/gsutil"
      args     = ["cp", "-r", "source/dist", google_storage_bucket.static-site.url]
      id       = "deploy"
      wait_for = ["build"]
    }
    logs_bucket = google_storage_bucket.logs-bucket.url
  }
}
