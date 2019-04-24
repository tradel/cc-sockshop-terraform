provider "google" {
  project = "${var.project_name}"
  region  = "${var.region}"
  version = "~> 2.3"
}

data "google_compute_image" "sockshop_image" {
  family = "sockshop-ambassador"
}

data "google_compute_network" "default" {
  name = "default"
}

resource "google_compute_firewall" "nginx" {
  name    = "allow-http-nginx"
  network = "${data.google_compute_network.default.name}"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags = ["web"]
}

resource "google_compute_firewall" "consul" {
  name    = "allow-consul-8500"
  network = "${data.google_compute_network.default.name}"

  allow {
    protocol = "tcp"
    ports    = ["8500"]
  }

  target_tags = ["consul-server"]
}

resource "google_compute_firewall" "ambassador" {
  name    = "allow-ambassador-8877"
  network = "${data.google_compute_network.default.name}"

  allow {
    protocol = "tcp"
    ports    = ["8877"]
  }

  target_tags = ["ambassador"]
}

