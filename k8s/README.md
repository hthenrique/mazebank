# EKS base

Arquivos base para subir o `mazebank` no Amazon EKS (profile **prod** + MongoDB Atlas).

## Variáveis

| Fonte | Conteúdo |
|-------|----------|
| `configmap.yaml` | `SPRING_PROFILES_ACTIVE=prod`, `PORT` |
| `secret.yaml` (a partir de `secret.example.yaml`) | `MONGO_CONNECTION_URL` do **Atlas** |

No CI, o workflow cria o Secret a partir do GitHub secret `MONGO_CONNECTION_URL`.

Para desenvolvimento local (Kind + IntelliJ), use [k8s/local/README.md](local/README.md) e `env.conf` — **não** a URL do Atlas.

## Ajustes antes do apply

1. Troque a imagem do `Deployment` pelo URI real do ECR em `deployment.yaml`.
2. Copie `secret.example.yaml` para `secret.yaml` e preencha `MONGO_CONNECTION_URL` (Atlas).
3. Se for usar domínio, adicione host e certificado ACM no `Ingress`.

## Apply

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

## Pré-requisitos AWS

- Cluster EKS criado
- `AWS Load Balancer Controller` instalado no cluster
- ECR com a imagem da aplicação
- `kubectl` configurado para o cluster

## Ambiente local

Preferir **Kind** em vez de `docker compose` no dia a dia (menos conflito de portas no host). Detalhes e fluxo de debug local: [k8s/local/README.md](local/README.md).

```bash
# WSL / Linux
./deploy-local-k8s.sh

# Windows
scripts\deploy-local-k8s.bat
```

O `Ingress` local usa `nginx`. No EKS, o `Ingress` usa `AWS Load Balancer Controller` com ALB.
