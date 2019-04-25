variable "project_name" {
    type        = "string"
    default     = "sockshop-ambassador-demo"
    description = "Name of the GCP project to create resources in."
}

variable "region" {
    type        = "string"
    default     = "us-east4"
    description = "GCP region to create resources in."
}

variable "zone" {
    type        = "string"
    default     = "us-east4-c"
    description = "GCP zone to create resources in."
}

variable "machine_type" {
    type        = "string"
    default     = "n1-standard-4"
    description = "Machine type to use."
}

variable "credentials" {
    type = "string"
    description = "Google service account credentials in JSON format"
}

module "gcp" {
    source       = "./modules/sock-shop-gcp"
    credentials  = "${var.credentials}"
    project_name = "${var.project_name}"
    region       = "${var.region}"
    zone         = "${var.zone}"
    machine_type = "${var.machine_type}"
}
