variable "project_id" {
  description = "ID del proyecto de Google Cloud"
  type        = string
}

variable "region" {
  description = "us-central1 es Iowa"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "vm_name" {
  type    = string
  default = "vm-spot-iowa"
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "image_family" {
  description = "Familia de Ubuntu. Comprueba si ya existe 26.04 con: gcloud compute images list --project ubuntu-os-cloud --filter=\"family~ubuntu-2604\""
  type        = string
  default     = "ubuntu-2604-lts-amd64"
}

variable "ssh_user" {
  type    = string
  default = "roberto"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/gcp_spot_iowa.pub"
}

variable "ssh_source_ranges" {
  description = "IPs que pueden entrar por SSH, por ejemplo tu IP: [\"203.0.113.10/32\"]. Sin valor por defecto a propósito: nunca abrir a 0.0.0.0/0."
  type        = list(string)
}
