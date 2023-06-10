variable "project" {
  default = "test-deploy-atip2"
}

variable "credentials_file" {}

variable "region" {
  default = "europe-west1"
}

variable "zone" {
  default = "europe-west1-a"
}

variable "secret_file" {
  default = ".secret"
}

variable "secret_id" {
  default = "deploy-atip-secret"
}

variable "service-account" {
  default = "deploy-atiper"
}
