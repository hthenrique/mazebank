$ErrorActionPreference = "Stop"

# Variaveis (Configuradas com os seus dados)
$compartmentId = "ocid1.tenancy.oc1..aaaaaaaasmcqpenira5hz776lrc4k3fpqs55mwhlw4tz4ke5iglctvmoxtwa" # Usando Tenancy como Compartment raiz
$region = "sa-saopaulo-1"
$sshKeyPath = "$HOME\.ssh\k3s_rsa"
$sshPubKeyPath = "$HOME\.ssh\k3s_rsa.pub"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🚀 Iniciando Criacao da Infraestrutura OCI" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Gerar Chave SSH se nao existir
if (-not (Test-Path $sshPubKeyPath)) {
    Write-Host "🔑 Gerando nova chave SSH para acesso ao servidor..."
    if (-not (Test-Path "$HOME\.ssh")) { New-Item -ItemType Directory -Path "$HOME\.ssh" | Out-Null }
    ssh-keygen -t rsa -b 4096 -f $sshKeyPath -N '""'
}
$sshPubKey = Get-Content $sshPubKeyPath -Raw

# 2. Criar VCN
Write-Host "🌐 Criando Rede Virtual (VCN)..."
$vcnJson = oci network vcn create --compartment-id $compartmentId --display-name "k3s-vcn" --cidr-block "10.0.0.0/16" --wait-for-state AVAILABLE --output json | ConvertFrom-Json
$vcnId = $vcnJson.data.id

# 3. Criar Internet Gateway
Write-Host "🌐 Criando Internet Gateway..."
$igwJson = oci network internet-gateway create --compartment-id $compartmentId --is-enabled true --vcn-id $vcnId --display-name "k3s-igw" --wait-for-state AVAILABLE --output json | ConvertFrom-Json
$igwId = $igwJson.data.id

# 4. Configurar Route Table
Write-Host "🌐 Atualizando Tabela de Rotas..."
$routeTableId = (oci network vcn get --vcn-id $vcnId --output json | ConvertFrom-Json).data."default-route-table-id"
$routeRules = @"
[{"cidrBlock":"0.0.0.0/0","networkEntityId":"$igwId"}]
"@
oci network route-table update --rt-id $routeTableId --route-rules $routeRules --force | Out-Null

# 5. Criar Subnet
Write-Host "🌐 Criando Subnet Publica..."
$subnetJson = oci network subnet create --compartment-id $compartmentId --vcn-id $vcnId --cidr-block "10.0.0.0/24" --display-name "k3s-subnet" --wait-for-state AVAILABLE --output json | ConvertFrom-Json
$subnetId = $subnetJson.data.id

# 6. Atualizar Security List (Liberar portas SSH, HTTP, HTTPS, 6443)
Write-Host "🔒 Atualizando Regras de Firewall (Security List)..."
$secListId = (oci network vcn get --vcn-id $vcnId --output json | ConvertFrom-Json).data."default-security-list-id"
$ingressRules = @"
[
  {"protocol": "6", "source": "0.0.0.0/0", "tcpOptions": {"destinationPortRange": {"max": 22, "min": 22}}},
  {"protocol": "6", "source": "0.0.0.0/0", "tcpOptions": {"destinationPortRange": {"max": 80, "min": 80}}},
  {"protocol": "6", "source": "0.0.0.0/0", "tcpOptions": {"destinationPortRange": {"max": 443, "min": 443}}},
  {"protocol": "6", "source": "0.0.0.0/0", "tcpOptions": {"destinationPortRange": {"max": 6443, "min": 6443}}}
]
"@
oci network security-list update --security-list-id $secListId --ingress-security-rules $ingressRules --force | Out-Null

# 7. Buscar AD e Image ID
Write-Host "🔍 Buscando Availability Domain e Imagem Ubuntu ARM..."
$ads = oci iam availability-domain list --compartment-id $compartmentId --output json | ConvertFrom-Json
$adName = $ads.data[0].name

# Buscando Ubuntu 22.04 ARM
$images = oci compute image list --compartment-id $compartmentId --operating-system "Canonical Ubuntu" --operating-system-version "22.04" --shape "VM.Standard.A1.Flex" --sort-by TIMECREATED --sort-order DESC --output json | ConvertFrom-Json
$imageId = $images.data[0].id

# 8. Criar Instancia
Write-Host "🚀 Criando a Maquina Virtual (4 OCPU, 24GB RAM - Always Free)... Isso pode levar alguns minutos."
$instanceJson = oci compute instance launch `
    --compartment-id $compartmentId `
    --availability-domain $adName `
    --shape "VM.Standard.A1.Flex" `
    --shape-config '{"ocpus": 4, "memoryInGBs": 24}' `
    --subnet-id $subnetId `
    --image-id $imageId `
    --display-name "k3s-server-1" `
    --assign-public-ip true `
    --ssh-authorized-keys-file $sshPubKeyPath `
    --wait-for-state RUNNING `
    --output json | ConvertFrom-Json

$instanceId = $instanceJson.data.id
$publicIp = (oci compute vnic-attachment list --compartment-id $compartmentId --instance-id $instanceId --output json | ConvertFrom-Json).data[0]."public-ip"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "✅ INSTANCIA CRIADA COM SUCESSO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "IP Publico: $publicIp" -ForegroundColor Yellow
Write-Host "Usuario: ubuntu" -ForegroundColor Yellow
Write-Host "Chave SSH: $sshKeyPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "Comando para acessar o servidor:" -ForegroundColor Cyan
Write-Host "ssh -i $sshKeyPath ubuntu@$publicIp"
