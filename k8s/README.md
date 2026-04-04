# EKS base

Arquivos base para subir o `mazebank` no Amazon EKS.

## Ajustes antes do apply

1. Troque a imagem do `Deployment` pelo URI real do ECR em `deployment.yaml`.
2. Copie `secret.example.yaml` para `secret.yaml` e preencha `MONGO_CONNECTION_URL`.
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

Os arquivos de apoio para Kubernetes local ficam em `k8s/local` e `k8s/overlays/local`.

Use o script da raiz:

```bat
deploy-local-k8s.bat
```

O `Ingress` local usa `nginx`. No EKS, o `Ingress` usa `AWS Load Balancer Controller` com ALB.
