#!/bin/bash
set -e

# Forca o uso da sessao SSO gerada pelo comando 'oci session authenticate'
export OCI_CLI_PROFILE=hthenrique
export OCI_CLI_AUTH=security_token

# Variaveis (Configuradas com os seus dados)
COMPARTMENT_ID="ocid1.tenancy.oc1..aaaaaaaasmcqpenira5hz776lrc4k3fpqs55mwhlw4tz4ke5iglctvmoxtwa"
REGION="sa-saopaulo-1"
SSH_DIR="$HOME/.ssh"
SSH_KEY_PATH="$SSH_DIR/k3s_rsa"
SSH_PUB_KEY_PATH="$SSH_DIR/k3s_rsa.pub"

echo -e "\e[36m==========================================\e[0m"
echo -e "\e[36m🚀 Iniciando Criacao da Infraestrutura OCI (Modo Idempotente)\e[0m"
echo -e "\e[36m==========================================\e[0m"

if [ ! -f "$SSH_PUB_KEY_PATH" ]; then
    echo -e "🔑 Gerando nova chave SSH para acesso ao servidor..."
    mkdir -p "$SSH_DIR"
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
fi
SSH_PUB_KEY=$(cat "$SSH_PUB_KEY_PATH")

echo "🌐 Buscando ou Criando Rede Virtual (VCN)..."
VCN_ID=$(oci network vcn list --compartment-id "$COMPARTMENT_ID" --display-name "k3s-vcn" --query 'data[0].id' --raw-output 2>/dev/null || echo "")
if [ "$VCN_ID" == "None" ] || [ -z "$VCN_ID" ]; then
    VCN_ID=$(oci network vcn create --compartment-id "$COMPARTMENT_ID" --display-name "k3s-vcn" --cidr-block "10.0.0.0/16" --wait-for-state AVAILABLE --query 'data.id' --raw-output)
fi

echo "🌐 Buscando ou Criando Internet Gateway..."
IGW_ID=$(oci network internet-gateway list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --display-name "k3s-igw" --query 'data[0].id' --raw-output 2>/dev/null || echo "")
if [ "$IGW_ID" == "None" ] || [ -z "$IGW_ID" ]; then
    IGW_ID=$(oci network internet-gateway create --compartment-id "$COMPARTMENT_ID" --is-enabled true --vcn-id "$VCN_ID" --display-name "k3s-igw" --wait-for-state AVAILABLE --query 'data.id' --raw-output)
fi

echo "🌐 Atualizando Tabela de Rotas..."
ROUTE_TABLE_ID=$(oci network vcn get --vcn-id "$VCN_ID" --query 'data."default-route-table-id"' --raw-output)
ROUTE_RULES='[{"cidrBlock":"0.0.0.0/0","networkEntityId":"'$IGW_ID'"}]'
oci network route-table update --rt-id "$ROUTE_TABLE_ID" --route-rules "$ROUTE_RULES" --force >/dev/null

echo "🌐 Buscando ou Criando Subnet Publica..."
SUBNET_ID=$(oci network subnet list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --display-name "k3s-subnet" --query 'data[0].id' --raw-output 2>/dev/null || echo "")
if [ "$SUBNET_ID" == "None" ] || [ -z "$SUBNET_ID" ]; then
    SUBNET_ID=$(oci network subnet create --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --cidr-block "10.0.0.0/24" --display-name "k3s-subnet" --wait-for-state AVAILABLE --query 'data.id' --raw-output)
fi

echo "🔒 Atualizando Regras de Firewall (Security List)..."
SEC_LIST_ID=$(oci network vcn get --vcn-id "$VCN_ID" --query 'data."default-security-list-id"' --raw-output)
INGRESS_RULES='[
  {"protocol": "6", "source": "0.0.0.0/0", "tcpOptions": {"destinationPortRange": {"max": 22, "min": 22}}},
  {"protocol": "6", "source": "0.0.0.0/0", "tcpOptions": {"destinationPortRange": {"max": 80, "min": 80}}},
  {"protocol": "6", "source": "0.0.0.0/0", "tcpOptions": {"destinationPortRange": {"max": 443, "min": 443}}},
  {"protocol": "6", "source": "0.0.0.0/0", "tcpOptions": {"destinationPortRange": {"max": 6443, "min": 6443}}}
]'
oci network security-list update --security-list-id "$SEC_LIST_ID" --ingress-security-rules "$INGRESS_RULES" --force >/dev/null

echo "🔍 Buscando Availability Domain e Imagem Ubuntu ARM..."
AD_NAME=$(oci iam availability-domain list --compartment-id "$COMPARTMENT_ID" --query 'data[0].name' --raw-output)
IMAGE_ID=$(oci compute image list --compartment-id "$COMPARTMENT_ID" --operating-system "Canonical Ubuntu" --operating-system-version "22.04" --shape "VM.Standard.A1.Flex" --sort-by TIMECREATED --sort-order DESC --query 'data[0].id' --raw-output)

echo "🚀 Buscando ou Criando a Maquina Virtual..."
while true; do
    INSTANCE_ID=$(oci compute instance list --compartment-id "$COMPARTMENT_ID" --display-name "k3s-server-1" --lifecycle-state RUNNING --query 'data[0].id' --raw-output 2>/dev/null || echo "")
    if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
        break
    fi

    echo "⏳ Tentando criar a instancia (Oracle A1 Flex)..."
    set +e
    LAUNCH_OUTPUT=$(oci compute instance launch \
        --compartment-id "$COMPARTMENT_ID" \
        --availability-domain "$AD_NAME" \
        --shape "VM.Standard.A1.Flex" \
        --shape-config '{"ocpus": 4, "memoryInGBs": 24}' \
        --subnet-id "$SUBNET_ID" \
        --image-id "$IMAGE_ID" \
        --display-name "k3s-server-1" \
        --assign-public-ip true \
        --ssh-authorized-keys-file "$SSH_PUB_KEY_PATH" \
        --wait-for-state RUNNING \
        --query 'data.id' --raw-output 2>&1)
    EXIT_CODE=$?
    set -e

    if [ $EXIT_CODE -ne 0 ]; then
        if echo "$LAUNCH_OUTPUT" | grep -iq "capacity"; then
            echo "❌ Falta de recursos na Oracle (Out of host capacity)."
        else
            echo "❌ Erro ao tentar criar a maquina: $LAUNCH_OUTPUT"
        fi
        echo "🔄 Tentando de novo em 60 segundos..."
        sleep 60
    else
        INSTANCE_ID=$(echo "$LAUNCH_OUTPUT" | tail -n 1)
        break
    fi
done

PUBLIC_IP=$(oci compute vnic-attachment list --compartment-id "$COMPARTMENT_ID" --instance-id "$INSTANCE_ID" --query 'data[0]."public-ip"' --raw-output)

echo -e "\e[32m==========================================\e[0m"
echo -e "\e[32m✅ INSTANCIA PRONTA COM SUCESSO!\e[0m"
echo -e "\e[32m==========================================\e[0m"
echo -e "\e[33mIP Publico: $PUBLIC_IP\e[0m"
echo -e "\e[33mUsuario: ubuntu\e[0m"
echo -e "\e[33mChave SSH: $SSH_KEY_PATH\e[0m"
echo ""
echo -e "\e[36mComando para acessar o servidor:\e[0m"
echo "ssh -i $SSH_KEY_PATH ubuntu@$PUBLIC_IP"
