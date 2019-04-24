resource "google_compute_instance" "server" {
  name         = "server"
  machine_type = "${var.machine_type}"
  zone         = "${var.zone}"

  tags = ["consul-server", "web", "ambassador"]

  boot_disk {
    initialize_params {
      image = "${data.google_compute_image.sockshop_image.self_link}"
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }

  connection {
    type        = "ssh"
    user        = "demo"
    agent       = false 
    private_key = "${file("${path.root}/files/ssh/id_ecdsa")}"
  }

  provisioner "file" {
    source       = "${path.root}/run/start.sh"
    destination  = "/tmp/start.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0755 /tmp/*.sh",
      "sudo /tmp/start.sh"
    ]
  }
}
