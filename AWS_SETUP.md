# AWS Setup

Este documento registra a configuracao realizada para publicar o projeto `mazebank` na AWS usando `EKS`, `ECR` e `GitHub Actions`.

## Arquitetura escolhida

- Aplicacao Java empacotada em container Docker
- Imagem publicada no `Amazon ECR`
- Aplicacao executada no `Amazon EKS`
- Exposicao HTTP via `Ingress`
- Automacao de deploy via `GitHub Actions` com autenticacao `OIDC`

## Regiao AWS

- `AWS_REGION`: `us-east-2`

## Amazon ECR

Repositorio criado:

- `mzb/mazebank`

URI base do repositorio:

- `650468121963.dkr.ecr.us-east-2.amazonaws.com/mzb/mazebank`

Configuracao importante:

- tag immutability habilitada
- sem filtros de exclusao

Observacao:

- o workflow nao faz mais push de `latest`
- o deploy usa tag de release semantica
- formato atual da tag:
  - `v<major>.<minor>.<patch>`
- a tag da imagem e derivada da versao do `pom.xml`
- se a imagem dessa versao ja existir no ECR, o workflow reutiliza a imagem em vez de tentar sobrescrever

## Amazon EKS

Cluster criado:

- `mazebank-cluster`

Namespace da aplicacao no Kubernetes:

- `mazebank`

Observacao:

- o nome do cluster e o nome do repositorio ECR sao independentes
- o namespace Kubernetes tambem e independente do ECR
- o EKS nao e uma opcao sem custo; ha cobranca pelo cluster e pelos recursos de compute

## Node group para laboratorio

Para um ambiente inicial de menor custo possivel, a configuracao recomendada do managed node group e:

- `Desired size = 1`
- `Minimum size = 1`
- `Maximum size = 1`
- `Disk size = 20 GiB`
- uma unica instancia no node group
- uma unica familia/tipo de instancia pequena

Configuracao de update observada:

- `Maximum unavailable = 1`
- `Update strategy = Default`

Observacao:

- essa configuracao reduz custo, mas nao elimina cobranca
- se nao existir node group ou profile adequado, os pods ficam em `Pending`
- o erro visto na console foi:
  - `FailedScheduling`
  - `no nodes available to schedule pods`

## IAM OIDC Provider

Provider correto para `GitHub Actions`:

- `https://token.actions.githubusercontent.com`

Audience:

- `sts.amazonaws.com`

Observacao importante:

- o provider `https://oidc.eks.us-east-2.amazonaws.com/id/...` nao e usado pelo GitHub Actions
- esse provider do EKS serve para IRSA dentro do cluster, nao para o pipeline do GitHub

## IAM Role para GitHub Actions

Role criada para o pipeline:

- `github-actions-eks-deploy`

ARN esperado para usar no GitHub:

- `arn:aws:iam::650468121963:role/github-actions-eks-deploy`

Essa role deve ser usada no secret:

- `AWS_ROLE_ARN`

## Trust policy da role do GitHub Actions

Para o `GitHub Actions` conseguir assumir a role via OIDC, a role precisa ter uma trust policy apontando para o provider correto do GitHub.

Estrutura esperada:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::650468121963:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<OWNER>/<REPO>:*"
        }
      }
    }
  ]
}
```

Observacoes:

- `<OWNER>` deve ser o usuario ou organizacao do repositorio no GitHub
- `<REPO>` deve ser o nome exato do repositorio
- para este projeto, o repositorio e `mazebank`

Exemplo:

```json
"token.actions.githubusercontent.com:sub": "repo:hthen/mazebank:*"
```

Se quiser restringir apenas a branch `master`, pode usar:

```json
"token.actions.githubusercontent.com:sub": "repo:hthen/mazebank:ref:refs/heads/master"
```

## Permissoes IAM da role do GitHub Actions

Policy AWS gerenciada anexada:

- `AmazonEC2ContainerRegistryPowerUser`

Policy custom necessaria:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster"
      ],
      "Resource": "*"
    }
  ]
}
```

Finalidade dessas permissoes:

- autenticar no ECR
- enviar imagem para o ECR
- executar `aws eks update-kubeconfig`

## Access Entry no EKS

Access entry criado para a role do GitHub Actions:

- principal ARN:
  - `arn:aws:iam::650468121963:role/github-actions-eks-deploy`
- type:
  - `Standard`

Policy recomendada para primeiro funcionamento:

- `AmazonEKSClusterAdminPolicy`

Motivo:

- permitir que o workflow execute `kubectl apply`, `kubectl rollout status` e operacoes administrativas no cluster durante a fase inicial
- permitir operar recursos de escopo de cluster, como `namespaces`

Observacao:

- depois que o deploy estiver estavel, essa permissao pode ser reduzida
- o access scope deve ser `Cluster`, nao apenas `Namespace`

## GitHub Actions

Workflows relevantes no repositorio:

- `/.github/workflows/release-version.yml`
- `/.github/workflows/deploy-eks.yml`
- `/.github/workflows/deploy.yml`

Comportamento atual:

- `release-version.yml` roda na `master`, calcula a proxima versao a partir de commits semanticos, atualiza o `pom.xml`, cria commit de release, publica a tag Git e cria uma `GitHub Release`
- `deploy-eks.yml` faz deploy automatico no EKS quando uma tag `v*` e publicada
- `deploy.yml` de Elastic Beanstalk foi deixado apenas para execucao manual

## GitHub Repository Variables

Variables necessarias:

- `AWS_REGION = us-east-2`
- `ECR_REPOSITORY = mzb/mazebank`
- `EKS_CLUSTER_NAME = mazebank-cluster`

## GitHub Repository Secrets

Secrets necessarios:

- `AWS_ROLE_ARN = arn:aws:iam::650468121963:role/github-actions-eks-deploy`
- `MONGO_CONNECTION_URL = <string de conexao real do MongoDB>`

## Manifests Kubernetes no projeto

Arquivos principais para AWS/EKS:

- [k8s/namespace.yaml](I:/Projetos/Java/mazebank/k8s/namespace.yaml)
- [k8s/configmap.yaml](I:/Projetos/Java/mazebank/k8s/configmap.yaml)
- [k8s/secret.example.yaml](I:/Projetos/Java/mazebank/k8s/secret.example.yaml)
- [k8s/deployment.yaml](I:/Projetos/Java/mazebank/k8s/deployment.yaml)
- [k8s/service.yaml](I:/Projetos/Java/mazebank/k8s/service.yaml)
- [k8s/ingress.yaml](I:/Projetos/Java/mazebank/k8s/ingress.yaml)

Observacao importante:

- o `deployment.yaml` usa uma imagem placeholder e o workflow substitui pelo URI real da imagem publicada no ECR

## Fluxo esperado de deploy no EKS

1. GitHub Actions faz checkout do repositorio
2. O workflow de release calcula o bump semantico:
   - `feat:` aumenta `minor`
   - `fix:` e demais commits aumentam `patch`
   - `BREAKING CHANGE` ou `!:` aumentam `major`
3. O workflow atualiza o `pom.xml`
4. O workflow cria commit `chore(release): vX.Y.Z [skip ci]`
5. O workflow cria a tag Git `vX.Y.Z`
6. O workflow cria a `GitHub Release`
7. A publicacao da tag dispara o workflow de deploy do EKS
8. O workflow de deploy builda a aplicacao com Maven
9. Builda a imagem Docker
10. Faz login no ECR
11. Publica a imagem com a mesma tag da release
   - se a imagem ja existir, o workflow reutiliza a tag existente
12. Atualiza o kubeconfig com `aws eks update-kubeconfig`
13. Cria/atualiza o secret `mazebank-secrets`
14. Aplica os manifests Kubernetes
15. Aguarda o rollout do deployment

## Problemas ja identificados durante a configuracao

1. `AWS_REGION`, `ECR_REPOSITORY` e `EKS_CLUSTER_NAME` ausentes nas variables do GitHub causavam falha em `configure-aws-credentials`
2. uso da role do cluster EKS era incorreto para o GitHub Actions
3. foi necessario criar uma role separada para o pipeline
4. o provider OIDC do EKS nao serve para GitHub Actions; o correto e `token.actions.githubusercontent.com`
5. o ECR com tags imutaveis exigiu ajuste no workflow para nao depender de `latest`
6. o erro `Not authorized to perform sts:AssumeRoleWithWebIdentity` indica problema na trust policy da role ou no `sub` configurado para o repositorio
7. o erro `cannot get resource "namespaces"` indica que a role conseguiu autenticar no EKS, mas ainda nao tem permissao suficiente dentro do cluster
8. para o workflow atual funcionar, a access entry da role `github-actions-eks-deploy` precisa usar `AmazonEKSClusterAdminPolicy` com escopo `Cluster`
9. com tag immutability habilitada no ECR, usar apenas `github.sha` faz a reexecucao do mesmo commit falhar com `tag invalid`
10. o fluxo foi alterado para usar versao semantica como tag de release e de imagem
11. se o workflow for executado novamente por erro de infraestrutura AWS, a imagem existente da mesma versao deve ser reutilizada em vez de gerar erro por tag imutavel

## Pendencias para confirmar

- confirmar que o secret `AWS_ROLE_ARN` foi salvo no GitHub
- confirmar que o secret `MONGO_CONNECTION_URL` foi salvo no GitHub
- confirmar que a trust policy da role `github-actions-eks-deploy` restringe corretamente o repositorio GitHub
- validar o primeiro deploy completo no EKS
- validar se todos os commits do time seguem Conventional Commits (`feat:`, `fix:`, etc.)

## Recomendada revisao futura

- reduzir a permissao `AmazonEKSClusterAdminPolicy` para algo mais restrito
- mover segredos sensiveis para `AWS Secrets Manager` ou `SSM Parameter Store`
- adicionar dominio real e TLS no `Ingress` da AWS
