output "ip_publica" {
  value = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

output "comando_ssh" {
  value = "ssh -i ~/.ssh/gcp_spot_iowa ${var.ssh_user}@${google_compute_instance.vm.network_interface[0].access_config[0].nat_ip}"
}

output "imagen_usada" {
  value = data.google_compute_image.ubuntu.name
}
