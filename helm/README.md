# Helm Chart - Mazebank

Este diretório contém o **Helm Chart unificado** para o `mazebank`, substituindo os antigos manifestos duplicados do Kubernetes (`k8s/` e `k8s/overlays/local`).

## Estrutura do Chart

```
helm/mazebank/
├── Chart.yaml             # Metadados do Helm Chart
├── values.yaml            # Valores padrão para Produção (Amazon EKS + Mongo Atlas)
├── values-local.yaml      # Sobrescritas para Desenvolvimento Local (Kind + Mongo local)
└── templates/
    ├── _helpers.tpl       # Helpers de nomes e labels Helm
    ├── namespace.yaml     # Namespace mazebank
    ├── configmap.yaml     # ConfigMap unificado
    ├── secret.yaml        # Secret condicional para Mongo Atlas (Prod)
    ├── deployment.yaml    # Deployment unificado da aplicação
    ├── service.yaml       # Service ClusterIP
    ├── ingress.yaml       # Ingress dinâmico (ALB para EKS / Nginx para Kind)
    └── mongodb.yaml       # MongoDB local + PVC (condicional se mongodb.enabled=true)
```

## Como usar

### 1. Desenvolvimento Local (Kind)

O script de deploy local automatiza a aplicação do chart usando `values-local.yaml`:

```bash
# Windows
scripts\deploy-local-k8s.bat

# Linux / WSL
./deploy-local-k8s.sh
```

Ou manualmente via Helm:

```bash
helm upgrade --install mazebank ./helm/mazebank \
  -n mazebank --create-namespace \
  -f ./helm/mazebank/values-local.yaml
```

### 2. Produção (Amazon EKS)

O GitHub Actions (`.github/workflows/deploy-eks.yml`) executa o deploy automaticamente no EKS:

```bash
helm upgrade --install mazebank ./helm/mazebank \
  --namespace mazebank --create-namespace \
  --set image.repository="SEU_ECR_URI" \
  --set image.tag="v1.0.0" \
  --set secret.create=true \
  --set secret.mongoConnectionUrl="SUA_URL_MONGO_ATLAS"
```

## Diferenças entre os ambientes (`values.yaml` vs `values-local.yaml`)

| Recurso | Produção (`values.yaml`) | Local (`values-local.yaml`) |
|---|---|---|
| **Réplicas** | 2 | 1 |
| **Imagem** | ECR (`Always`) | `mazebank:local` (`IfNotPresent`) |
| **Profile Spring** | `prod` | `local` |
| **MongoDB** | Externalizado (Atlas via Secret) | Container no cluster (`mongodb.enabled: true`) |
| **Ingress** | AWS ALB Controller | Nginx (`host: mazebank.local`) |
