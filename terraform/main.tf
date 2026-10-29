terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# La imagen se pide por "familia": GCP devuelve siempre la última versión
# parcheada de esa familia, así la VM nace con Ubuntu actualizado.
data "google_compute_image" "ubuntu" {
  family  = var.image_family
  project = "ubuntu-os-cloud"
}

resource "google_compute_instance" "vm" {
  name         = var.vm_name
  machine_type = var.machine_type # e2-standard-2 = 2 vCPU y 8 GB de RAM
  zone         = var.zone
  tags         = ["ssh"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 20 # GB
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
    # Bloque vacío = IP pública efímera, necesaria para entrar por SSH desde fuera.
    access_config {}
  }

  # Spot: mucho más barata, pero Google puede pararla cuando necesite la capacidad.
  scheduling {
    provisioning_model          = "SPOT"
    preemptible                 = true
    automatic_restart           = false
    on_host_maintenance         = "TERMINATE"
    instance_termination_action = "STOP" # se apaga (no se borra) y conserva el disco
  }

  # GCP crea el usuario y mete la clave pública en su authorized_keys.
  metadata = {
    ssh-keys = "${var.ssh_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }

  # Al primer arranque, instala las actualizaciones pendientes.
  metadata_startup_script = <<-EOT
    #!/bin/bash
    if [ ! -f /var/lib/primer-arranque-hecho ]; then
      apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
      touch /var/lib/primer-arranque-hecho
    fi
  EOT
}

resource "google_compute_firewall" "ssh" {
  name    = "${var.vm_name}-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["ssh"]
}
