variable "project_name" {
    type = "string"
    description = "Name of the GCP project to create resources in."
}

variable "region" {
    type    = "string"
    default = "us-east1"
    description = "GCP region to create resources in."
}

variable "zone" {
    type    = "string"
    default = "us-east1-c"
    description = "GCP zone to create resources in."
}

variable "machine_type" {
    type = "string"
    default = "n1-standard-4"
    description = "Machine type to use."
}
