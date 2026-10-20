#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -eq 0 ]]; then
  echo "Ejecuta el script con tu usuario normal, sin sudo delante."
  exit 1
fi
if ! command -v apt-get >/dev/null 2>&1 || ! command -v dpkg >/dev/null 2>&1; then
  echo "Error: se requiere Ubuntu/Debian con apt."
  exit 1
fi

. /etc/os-release
os_id="${ID:-unknown}"
os_version="${VERSION_ID:-unknown}"
codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
arch="$(dpkg --print-architecture)"

if [[ "$os_id" != "ubuntu" ]]; then
  echo "Aviso: sistema detectado: $os_id $os_version."
fi
if [[ -z "$codename" ]]; then
  echo "Error: no se pudo detectar el codename del sistema."
  exit 1
fi

case "$arch" in
  amd64) aws_arch="x86_64"; kiro_platform="linux-x64" ;;
  arm64) aws_arch="aarch64"; kiro_platform="linux-arm64" ;;
  *) echo "Error: arquitectura no compatible: $arch"; exit 1 ;;
esac

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "==> Sistema: $os_id $os_version ($arch)"
echo "==> Instalando dependencias y Python..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl git gnupg jq openssh-client python3 python-is-python3 python3-pip python3-venv unzip wget

echo "==> Instalando Visual Studio Code..."
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "$tmpdir/microsoft.gpg"
sudo install -o root -g root -m 0644 "$tmpdir/microsoft.gpg" /etc/apt/keyrings/microsoft-archive-keyring.gpg
echo "deb [arch=$arch signed-by=/etc/apt/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
sudo apt-get update
sudo apt-get install -y code

echo "==> Instalando AWS CLI v2..."
(
  cd "$tmpdir"
  curl -fsSL --retry 2 "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o awscliv2.zip
  unzip -q awscliv2.zip
  if command -v aws >/dev/null 2>&1; then
    sudo ./aws/install --update
  else
    sudo ./aws/install
  fi
)

echo "==> Instalando Terraform..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$arch signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
sudo apt-get update
sudo apt-get install -y terraform

echo "==> Instalando Kiro desde los metadatos oficiales..."
metadata_url="https://prod.download.desktop.kiro.dev/stable/metadata-${kiro_platform}-stable.json"
kiro_version="$(curl -fsSL --retry 3 --connect-timeout 20 "$metadata_url" | jq -er '.currentRelease | strings | select(length > 0)')"
kiro_url="https://prod.download.desktop.kiro.dev/releases/stable/${kiro_platform}/signed/${kiro_version}/deb/kiro-ide-${kiro_version}-stable-${kiro_platform}.deb"

curl -fL --retry 3 --connect-timeout 20 "$kiro_url" -o "$tmpdir/kiro-ide.deb"
dpkg-deb --info "$tmpdir/kiro-ide.deb" >/dev/null
sudo apt-get install -y "$tmpdir/kiro-ide.deb"

echo "==> Reparando dependencias de paquetes..."
sudo apt-get install -f -y

echo "==> Validando herramientas..."
command -v code >/dev/null
command -v git >/dev/null
command -v aws >/dev/null
command -v terraform >/dev/null
command -v python >/dev/null
command -v python3 >/dev/null
command -v ssh >/dev/null
command -v curl >/dev/null
command -v jq >/dev/null

code --version | head -n 1
git --version
aws --version
terraform -version | head -n 1
python --version
python3 --version
ssh -V 2>&1 | head -n 1
curl --version | head -n 1
jq --version

echo "==> Comprobando el paquete y el acceso de escritorio de Kiro..."
dpkg-query -W -f='${Package} ${Status} ${Version}\n' 'kiro*' 2>/dev/null | grep 'install ok installed' || {
  echo "Error: el paquete de Kiro no figura como instalado."
  exit 1
}
find /usr/share/applications -maxdepth 1 -iname '*kiro*.desktop' -print
echo "==> Instalación finalizada. Abre Kiro desde el menú de aplicaciones."
