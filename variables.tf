variable "project" {
  default = "test-deploy-atip"
}

variable "credentials_file" {}

variable "region" {
  default = "europe-west2"
}

variable "zone" {
  default = "europe-west2-a"
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
