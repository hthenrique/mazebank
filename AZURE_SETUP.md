# Azure Setup & Deploy Guide

Este documento registra a arquitetura e o procedimento de deploy do projeto `mazebank` no **Azure Kubernetes Service (AKS)** utilizando o **WSL 2 (Ubuntu)**.

---

## 1. Arquitetura na Azure

- **Container Engine & Cloud Build**: Azure Container Registry (ACR) com build remoto via `az acr build` (sem necessidade do Docker Desktop estar ativo localmente).
- **Orquestrador de Containers**: Azure Kubernetes Service (AKS).
- **Gerenciador de Pacotes**: Helm (Chart customizado em `helm/mazebank`).
- **Exposicao de Rede**: Azure Load Balancer (Service `LoadBalancer` no Kubernetes), atribuindo um IP publico direto para a aplicacao na porta 80.
- **Banco de Dados**: MongoDB Atlas externalizado (ou instanciado via Kubernetes).
- **Configuracao & Segredos**: Injetados a partir de `ENV/real/env.conf` diretamente no ConfigMap `mazebank-config`.

---

## 2. Recursos no Azure

Recursos padrao configurados no ambiente:

- **Subscription**: `Azure subscription 1`
- **Resource Group**: `MyResourceGroupAKS-BR`
- **Localizacao**: `brazilsouth` (Brasil Sul)
- **Cluster AKS**: `MyClusterAKS`
- **Registro ACR**: `mazebankacr` (criado e vinculado automaticamente via `--attach-acr`)
- **Namespace Kubernetes**: `mazebank`

---

## 3. Pre-requisitos no WSL (Ubuntu)

O script foi projetado para rodar a partir do seu WSL 2 (Ubuntu).

As seguintes ferramentas sao necessarias e estao localizadas no PATH (`$HOME/.local/bin` ou `/usr/bin`):

1. **Azure CLI (`az`)**:
   ```bash
   az version
   az account show
   ```
2. **Kubernetes CLI (`kubectl`)**:
   ```bash
   kubectl version --client
   ```
3. **Helm (`helm`)**:
   ```bash
   helm version
   ```

---

## 4. Como Executar o Deploy

### Opcao A: Executando direto no terminal WSL

No seu terminal WSL Ubuntu, dentro do diretorio do projeto:

```bash
# Deploy completo (build no ACR + deploy no AKS)
./scripts/deploy-azure-aks.sh deploy real

# Acompanhar os logs da aplicacao
./scripts/deploy-azure-aks.sh logs

# Verificar status dos pods e servicos
./scripts/deploy-azure-aks.sh status
```

### Opcao B: Executando a partir do Windows (PowerShell ou CMD)

Voce tambem pode disparar o wrapper Windows que delega a execucao para o WSL:

```powershell
# No PowerShell / CMD da raiz do projeto:
.\scripts\deploy-azure-aks.bat deploy real

# Verificar status:
.\scripts\deploy-azure-aks.bat status

# Ver logs:
.\scripts\deploy-azure-aks.bat logs
```

---

## 5. Parametros e Opcoes do Script

| Parametro | Descricao | Padrao |
| :--- | :--- | :--- |
| `[real\|local]` | Ambiente com variaveis em `ENV/<env>/env.conf` | `real` |
| `--skip-build` | Pula a etapa de compilacao da imagem no ACR e reaproveita a existente | Desativado |
| `--acr <nome>` | Sobrescreve o nome do Azure Container Registry | `mazebankacr` |
| `--rg <nome>` | Sobrescreve o Resource Group | `MyResourceGroupAKS-BR` |
| `--cluster <nome>` | Sobrescreve o nome do cluster AKS | `MyClusterAKS` |
| `--tag <versao>` | Define uma tag customizada | Versao do `pom.xml` |

---

## 6. Endpoints Disponibilizados

A aplicacao possui tanto IP publico quanto um Dominio DNS oficial gratuito gerado pela Azure:

- **Dominio Publico Azure**: `http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank`
- **Actuator Health**: `http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/actuator/health`
- **Readiness Probe**: `http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/actuator/health/readiness`
- **Liveness Probe**: `http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/actuator/health/liveness`
- **IP Direto (Load Balancer)**: `http://191.235.56.113/mazebank`

---

## 7. Desinstalacao / Limpeza

Para remover a aplicacao e liberar os recursos do cluster AKS:

```bash
./scripts/deploy-azure-aks.sh destroy
```
