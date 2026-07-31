# Local Kubernetes (Kind)

Ambiente local recomendado no **Linux/WSL** (e Windows). Evita o conflito de portas do `docker compose` (`8080` / `27017` no host): no Kind a app fica atrás do Ingress na **porta 80** e o Mongo só é publicado no host quando você for debugar no IntelliJ.

## Variáveis por ambiente

| Onde | Profile | Mongo |
|------|---------|--------|
| IntelliJ / Maven no host | `local` | Kind via port-forward → `127.0.0.1:27017` (copie `env.conf`) |
| App dentro do Kind | `local` | `mongodb://mongo:27017` (ConfigMap do overlay) |
| EKS / deploy | `prod` | MongoDB Atlas via Secret / GitHub secret |

Nunca use a URL do Atlas no IntelliJ ou no overlay local.

## Pré-requisitos

- Docker em execução
- [kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Subir tudo no Kind

**WSL / Linux:**

```bash
chmod +x deploy-local-k8s.sh scripts/k8s-debug-local.sh
./deploy-local-k8s.sh
```

**Windows (PowerShell/CMD):**

```bat
scripts\deploy-local-k8s.bat
```

URL: http://mazebank.local/mazebank/actuator/health

O script cria o cluster Kind (se não existir), instala `ingress-nginx`, builda `mazebank:local`, carrega a imagem e aplica `k8s/overlays/local` (app + Mongo com PVC).

## Debug no IntelliJ (app local + Mongo no Kind)

A app no Kind continua no ar. Só o Mongo é publicado no host:

```bash
./scripts/k8s-debug-local.sh start
```

No Windows: `scripts\k8s-debug-local.bat start`.

Depois, na Run/Debug Configuration do IntelliJ, cole as variáveis de `env.conf`:

```
PORT=8080
SPRING_PROFILES_ACTIVE=local
MONGO_CONNECTION_URL=mongodb://127.0.0.1:27017
```

- Local (debug): http://localhost:8080/mazebank/...
- Kind (deploy local): http://mazebank.local/mazebank/...
- Ambos usam o **mesmo Mongo do Kind**, não o Atlas.

Ao terminar o port-forward:

```bash
./scripts/k8s-debug-local.sh stop
```

## Portas no host

| Serviço | Compose (legado) | Kind (padrão) | Debug IntelliJ |
|---------|------------------|---------------|----------------|
| App     | 8080             | 80 via Ingress (`mazebank.local`) | 8080 no host |
| Mongo   | 27017            | só dentro do cluster | 27017 via port-forward |

## Arquivos

- `kind-config.yaml` — mapeia 80/443 do host para o nó Kind
- `../overlays/local` — Namespace, ConfigMap, Mongo (PVC), app, Ingress nginx
- `../../ENV/local/env.conf` — variáveis para colar no IntelliJ

## Limpar

```bash
kind delete cluster --name mazebank
```
