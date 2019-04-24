
output "consul_ip_address" {
    value = "${google_compute_instance.server.network_interface.0.access_config.0.nat_ip}"
    description = "Public IP address of the server"
}

output "app_url" {
    value = "http://${google_compute_instance.server.network_interface.0.access_config.0.nat_ip}/"
    description = "URL for the Sock Shop site"
}

output "consul_url" {
    value = "http://${google_compute_instance.server.network_interface.0.access_config.0.nat_ip}:8500/"
    description = "URL for the Consul UI"
}
