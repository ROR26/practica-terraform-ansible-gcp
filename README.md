# Práctica: Terraform + Ansible en Google Cloud

Ejercicio de aprendizaje del máster de CodeCrypto. Se crea una VM spot en Google Cloud con **Terraform** y se configura con **Ansible** para que tenga la misma infraestructura que una VM local: Docker con MongoDB, PostgreSQL, RustFS y Mailpit. Después se comprueba que las dos máquinas son iguales y se destruye la VM.

La idea central: **el mismo playbook** (`up.yml`) levanta los servicios en la máquina local y en la remota.

## Estructura

| Carpeta / archivo | Qué es |
|---|---|
| `terraform/main.tf` | VM spot `e2-standard-2` (2 vCPU, 8 GB) con 20 GB y Ubuntu 26.04 en `us-central1-a`, y la regla de firewall para SSH |
| `terraform/variables.tf` | Zona, tipo de máquina, imagen, usuario, clave SSH e IPs permitidas |
| `terraform/outputs.tf` | IP pública, comando SSH e imagen usada |
| `terraform/terraform.tfvars.example` | Plantilla: copiar a `terraform.tfvars` y poner el proyecto y tu IP |
| `ansible/inventory.ini` | Grupo `vm` (máquina local) y grupo `gcp` (la VM de Google) |
| `ansible/preparar.yml` | Deja la VM remota lista: instala Docker y copia `docker-compose.yml` y `.env` |
| `ansible/up.yml` | Valida el `.env` y los puertos, y levanta los servicios. Sirve para las dos máquinas |
| `ansible/down.yml` | Para o baja los servicios; pide escribir `BORRAR` para eliminar datos |
| `ansible/verificar.yml` | Compara todas las máquinas y prueba que cada servicio responde |
| `ansible/docker-compose.yml` | Los 4 servicios, todos escuchando solo en `127.0.0.1` |
| `ansible/.env.example` | Plantilla del `.env` (usuarios, contraseñas y puertos) |

## Requisitos

- Una cuenta de Google Cloud con un proyecto y la API de Compute Engine activada.
- `terraform` (≥ 1.5), `gcloud` y `ansible-core` con la colección `community.docker`.
- Docker en la máquina local.
- Una clave SSH para la VM: `ssh-keygen -t ed25519 -f ~/.ssh/gcp_spot_iowa`.

## Pasos

```bash
# 1. Credenciales para Terraform
gcloud auth application-default login

# 2. Crear la VM
cd terraform
cp terraform.tfvars.example terraform.tfvars    # pon tu project_id y tu IP
terraform init
terraform plan -out=tfplan
terraform apply tfplan                         # anota ip_publica

# 3. Configurarla con Ansible
cd ../ansible
cp .env.example .env && chmod 600 .env         # cambia todos los valores 'cambiar'
# en inventory.ini: descomenta vm-spot-iowa y pon la IP
ansible gcp -m ping
ansible-playbook preparar.yml
ansible-playbook up.yml -l gcp
ansible-playbook verificar.yml

# 4. Destruirla
cd ../terraform
terraform destroy
```

## Cómo funciona

- **Un playbook para dos máquinas.** En `inventory.ini`, el grupo `gcp` define `infra_dir`. `up.yml` usa `infra_dir` si existe y, si no, la carpeta del playbook:
  ```yaml
  project_dir: "{{ infra_dir | default(playbook_dir) }}"
  ```
- **Primer arranque.** Terraform lanza un `apt upgrade` al crear la VM. `preparar.yml` espera a que termine antes de instalar Docker, para no chocar con el bloqueo de `apt`.
- **Idempotencia.** Los playbooks se pueden lanzar varias veces: solo cambian lo que falte.
- **Arquitecturas distintas.** La VM local era ARM (`aarch64`) y la de Google x86 (`x86_64`). Ansible y las imágenes multiarquitectura de Docker lo resuelven sin cambios.

## Seguridad

- **SSH solo desde tu IP.** `ssh_source_ranges` no tiene valor por defecto: Terraform obliga a indicarlo, para no abrir nunca el puerto 22 a `0.0.0.0/0`. Si tu IP cambia, actualízala y haz `terraform apply`.
- **Los servicios no se exponen a internet.** Todos escuchan en `127.0.0.1`, también en Google. Para ver la bandeja de Mailpit, usa un túnel SSH:
  ```bash
  ssh -i ~/.ssh/gcp_spot_iowa -N -L 18025:127.0.0.1:8025 roberto@<ip_publica>
  # y abre http://localhost:18025
  ```
- **Secretos fuera de git.** `.env`, `terraform.tfvars` y el estado de Terraform están en `.gitignore`. `preparar.yml` copia el `.env` a la VM con permisos `600` y sin mostrarlo en la salida (`no_log`).
- **VM spot.** Google puede apagarla en cualquier momento. Está configurada para pararse (`STOP`), no para borrarse.

## Detalle útil de Ansible

En las órdenes de Ansible, las llaves `{{ }}` son plantillas de Ansible. Para pasárselas a Docker hay que escaparlas:

```bash
ansible docker -a "docker ps --format '{{ '{{' }}.Names{{ '}}' }}'"
```

## Evidencia (29 oct 2026)

Las IPs se han sustituido por `<ip_vm>` y `<mi_ip>`.

**`terraform apply`**
```
google_compute_firewall.ssh: Creation complete after 23s
google_compute_instance.vm: Creation complete after 27s
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
imagen_usada = "ubuntu-2604-resolute-amd64-v20261021"
```

**`gcloud compute instances describe` y `firewall-rules describe`**
```
machineType: e2-standard-2
scheduling:
  instanceTerminationAction: STOP
  provisioningModel: SPOT
status: RUNNING
zone: us-central1-a

allowed: tcp 22
sourceRanges: <mi_ip>/32
```

**`ansible gcp -m ping`**
```
vm-spot-iowa | SUCCESS => { "changed": false, "ping": "pong" }
```

**`ansible-playbook preparar.yml`**: primera pasada `changed=5`; segunda pasada:
```
vm-spot-iowa : ok=8  changed=0  unreachable=0  failed=0
```

**`ansible-playbook up.yml -l gcp`**
```
"mailpit: running", "mongodb: running", "postgres: running", "rustfs: running"
vm-spot-iowa : ok=10  changed=1  unreachable=0  failed=0
```

**`ansible-playbook verificar.yml`**
```
localhost:
  Sistema: Ubuntu 26.04 (aarch64)
  Docker 29.1.3 · Compose 2.40.3
  Contenedores: mailpit=running/healthy, mongodb=running, postgres=running/healthy, rustfs=running
  Pruebas: postgres=responde, mongodb=responde, mailpit=responde, rustfs=responde
  Puertos abiertos a la red: ninguno
vm-spot-iowa:
  Sistema: Ubuntu 26.04 (x86_64)
  Docker 29.1.3 · Compose 2.40.3
  Contenedores: mailpit=running/healthy, mongodb=running, postgres=running/healthy, rustfs=running
  Pruebas: postgres=responde, mongodb=responde, mailpit=responde, rustfs=responde
  Puertos abiertos a la red: ninguno
```

**Dentro de la VM de Google** (por SSH)
```
preemptible: TRUE
postgres: Up 11 minutes (healthy)
mongodb: Up 11 minutes
rustfs: Up 11 minutes
mailpit: Up 11 minutes (healthy)
```

**`terraform destroy`**
```
google_compute_firewall.ssh: Destruction complete after 11s
google_compute_instance.vm: Destruction complete after 1m2s
Destroy complete! Resources: 2 destroyed.
```
Comprobación posterior en Google: 0 instancias, 0 discos, 0 reglas de firewall y el estado de Terraform vacío.

## Diferencia con lo que se ejecutó

En la práctica, `ssh_source_ranges` tenía `0.0.0.0/0` por defecto y se restringió a la IP de casa en `terraform.tfvars`. En esta versión pública se quitó ese valor por defecto, para que nadie lo use abierto por descuido.
