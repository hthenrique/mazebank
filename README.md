# Mazebank Application

API bancária desenvolvida em **Java 17** com **Spring Boot 2.7**, utilizando **MongoDB Atlas** para persistência de dados de usuários e saldos, **PingDirectory (Ping Identity / LDAP)** para autenticação e gestão de credenciais, implantada no **Azure Kubernetes Service (AKS)**.

---

## 🌐 Endpoints e Ambientes

| Ambiente | Host / Base URL |
| :--- | :--- |
| **Azure AKS (Domínio Público Oficial)** | `http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank` |
| **Azure AKS (IP Load Balancer)** | `http://191.235.56.113/mazebank` |
| **Local (Kind / Docker)** | `http://mazebank.local/mazebank` ou `http://localhost:8080/mazebank` |

> Defina uma variável de ambiente no seu terminal para facilitar as chamadas:
> ```bash
> export BASE_URL="http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank"
> ```

---

## 🚀 Guia de Endpoints (Exemplos cURL)

### 1. Healthcheck e Probes (Actuator)

Verifica a saúde da aplicação, probes de liveness e readiness do Kubernetes.

#### 1.1 Saúde Geral
```bash
curl -i -X GET "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/actuator/health"
```
**Resposta esperada (HTTP 200):**
```json
{
  "status": "UP",
  "groups": [
    "liveness",
    "readiness"
  ]
}
```

#### 1.2 Readiness Probe
```bash
curl -i -X GET "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/actuator/health/readiness"
```
**Resposta (HTTP 200):** `{"status":"UP"}`

#### 1.3 Liveness Probe
```bash
curl -i -X GET "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/actuator/health/liveness"
```
**Resposta (HTTP 200):** `{"status":"UP"}`

---

### 2. Criar Usuário (Cadastro)

Cria o usuário simultaneamente no **MongoDB Atlas** (dados cadastrais e saldo inicial de $100.00) e no **PingDirectory LDAP** (credenciais criptografadas em `ou=people,dc=example,dc=com`).

#### cURL (Bash / WSL / macOS):
```bash
curl -i -X POST "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/management/create" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "Carlos Silva",
    "useremail": "carlos.silva@example.com",
    "userpass": "MinhaSenha@123"
  }'
```

#### PowerShell (Windows):
```powershell
Invoke-RestMethod -Uri "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/management/create" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{
    "username": "Carlos Silva",
    "useremail": "carlos.silva@example.com",
    "userpass": "MinhaSenha@123"
  }'
```

**Resposta esperada (HTTP 200):**
```json
{
  "code": "201000",
  "response": {
    "message": "Success"
  }
}
```

---

### 3. Autenticar Usuário (Login)

Autentica as credenciais diretamente no **PingDirectory (LDAP)**. Permite login utilizando o e-mail cadastrado ou o username.

#### cURL (Bash / WSL / macOS):
```bash
curl -i -X POST "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/authenticate/user" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "carlos.silva@example.com",
    "userpass": "MinhaSenha@123"
  }'
```

#### PowerShell (Windows):
```powershell
Invoke-RestMethod -Uri "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/authenticate/user" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{
    "username": "carlos.silva@example.com",
    "userpass": "MinhaSenha@123"
  }'
```

**Resposta esperada (HTTP 200):**
```json
{
  "code": "200000",
  "response": {
    "message": "Success"
  }
}
```

---

### 4. Consultar Dados do Usuário

Busca as informações cadastrais e o saldo da conta no MongoDB. O header `user-key` aceita o e-mail ou o username do usuário.

#### cURL (Bash / WSL / macOS):
```bash
curl -i -X GET "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/management/fetch/user" \
  -H "user-key: carlos.silva@example.com"
```

#### PowerShell (Windows):
```powershell
Invoke-RestMethod -Uri "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/management/fetch/user" `
  -Headers @{ "user-key" = "carlos.silva@example.com" }
```

**Resposta esperada (HTTP 200):**
```json
{
  "code": "200000",
  "response": {
    "uid": "6ac7000ff79a34403761b6d0",
    "userName": "Carlos Silva",
    "userEmail": "carlos.silva@example.com",
    "userCreateDate": "2026-10-08T02:29:35.470270461",
    "userBalance": 100.0
  }
}
```

---

### 5. Depositar Saldo na Conta

Realiza um depósito na conta do usuário, incrementando o `userBalance` no MongoDB Atlas.
Requer o header `user-uid` contendo o `uid` retornado na consulta do usuário.

#### cURL (Bash / WSL / macOS):
```bash
curl -i -X POST "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/management/deposit/user" \
  -H "Content-Type: application/json" \
  -H "user-uid: 6ac7000ff79a34403761b6d0" \
  -d '{
    "value": 50.0
  }'
```

#### PowerShell (Windows):
```powershell
Invoke-RestMethod -Uri "http://mazebank-app.brazilsouth.cloudapp.azure.com/mazebank/management/deposit/user" `
  -Method Post `
  -Headers @{ "user-uid" = "6ac7000ff79a34403761b6d0" } `
  -ContentType "application/json" `
  -Body '{
    "value": 50.0
  }'
```

**Resposta esperada (HTTP 200):**
```json
{
  "code": "200000",
  "response": null
}
```

*(Ao consultar o usuário novamente via `/management/fetch/user`, o campo `userBalance` refletirá o novo saldo, ex: `150.0`)*.

---

## 🛠️ Comandos de Deploy e Operação

### Deploy no Azure Kubernetes Service (AKS) via WSL:
```bash
# Executar deploy completo no Azure
./scripts/deploy-azure-aks.sh deploy real

# Verificar status dos pods e serviços
./scripts/deploy-azure-aks.sh status

# Acompanhar logs em tempo real
./scripts/deploy-azure-aks.sh logs
```

### Executando pelo Windows (PowerShell/CMD):
```powershell
.\scripts\deploy-azure-aks.bat deploy real
.\scripts\deploy-azure-aks.bat status
.\scripts\deploy-azure-aks.bat logs
```

---

## 📄 Postman Collection

O repositório também inclui o arquivo [`Mazebank.postman_collection.json`](./Mazebank.postman_collection.json) pronto para ser importado no Postman.
Basta configurar a variável `service-url` no Postman com:
```text
http://mazebank-app.brazilsouth.cloudapp.azure.com
```
