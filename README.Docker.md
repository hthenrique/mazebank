### Ambiente local recomendado (Kind)

No Linux/WSL, use Kind para não ocupar `8080`/`27017` no host:

```bash
./deploy-local-k8s.sh
```

URL: http://mazebank.local/mazebank/actuator/health  

Debug no IntelliJ (Mongo do Kind, sem Atlas): `./scripts/k8s-debug-local.sh start` e cole `env.conf` na Run Configuration. Ver `helm/README.md`.

### Docker Compose (legado)

`docker compose up --build` sobe app + Mongo nas portas do host (`8080`, `27017`) e pode conflitar com outros serviços.

### Deploying your application to the cloud

First, build your image, e.g.: `docker build -t myapp .`.
If your cloud uses a different CPU architecture than your development
machine (e.g., you are on a Mac M1 and your cloud provider is amd64),
you'll want to build the image for that platform, e.g.:
`docker build --platform=linux/amd64 -t myapp .`.

Then, push it to your registry, e.g. `docker push myregistry.com/myapp`.

Consult Docker's [getting started](https://docs.docker.com/go/get-started-sharing/)
docs for more detail on building and pushing.