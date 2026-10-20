# Punto0
Grupo 4

# Instalación de herramientas en Ubuntu

## 1. Actualizar los repositorios e instalar dependencias

```bash
sudo apt update
sudo apt install -y git python3 python3-pip python3-venv openssh-client curl jq unzip wget gnupg software-properties-common lsb-release
```

## 2. AWS CLI v2

```bash
curl -fsSL https://awscli.amazonaws.com/v2/install.sh | sudo bash -s -- --system
```

## 3. Git

```bash
sudo apt install -y git
```

## 4. Terraform

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install -y terraform
```

## 5. Python 3

```bash
sudo apt install -y python3 python3-pip python3-venv
```

## 6. OpenSSH

```bash
sudo apt install -y openssh-client
```

## 7. curl

```bash
sudo apt install -y curl
```

## 8. jq (recomendado)

```bash
sudo apt install -y jq
```
prueba push

instalaciones:

vAWS CLI v2 (aws)
irm https://awscli.amazonaws.com/v2/install.ps1 | iex 

TERRAFORM
Ruta -> C:\Users\Usuario\Terraform     (dentro va el .exe)

En PowerShell:
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Users\Usuario\Terraform", "User")
[Environment]::GetEnvironmentVariable("Path", "User") 
al final tendria que salir la ruta de terraform 

..

