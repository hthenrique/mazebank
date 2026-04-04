# Local Kubernetes

Arquivos de apoio para desenvolvimento local com `kind` e `ingress-nginx`.

## Fluxo

Use o script da raiz:

```bat
deploy-local-k8s.bat
```

Ele usa:

- `kind-config.yaml` para criar o cluster local
- `../overlays/local` para subir Mongo, aplicação e Ingress
