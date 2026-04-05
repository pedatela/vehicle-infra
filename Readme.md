### Terraform para Core + Sales + Cognito

O diretório `terraform/` provisiona toda a infraestrutura necessária para os **dois serviços** (Core e Sales) e para o mecanismo de autenticação via Amazon Cognito:

- VPC dedicada com sub-redes públicas, IGW, rotas e security groups.
- Dois repositórios ECR, duas definições ECS Fargate e dois Application Load Balancers (um por serviço), respeitando o isolamento pedido.
- Cognito User Pool + App Client + domínio público para o fluxo OAuth/JWT consumido pelo Core.

Para usar localmente:

```bash
cd terraform
terraform init \
  -backend-config="bucket=<bucket-state>" \
  -backend-config="key=<prefixo>/terraform.tfstate" \
  -backend-config="region=<aws-region>" \
  -backend-config="dynamodb_table=<tabela-lock>"
terraform plan \
  -var-file=<opcional>.tfvars
terraform apply \
  -var-file=<opcional>.tfvars
```

Variáveis úteis:

- `core_app_container_image` / `sales_app_container_image`: sobrescrevem a imagem enviada para cada serviço.
- `core_app_container_port` / `sales_app_container_port`: portas expostas pelas tasks.
- `core_app_desired_count` / `sales_app_desired_count`: quantidade de tasks Fargate (permitindo escalar o Sales independentemente).
- `sales_internal_sync_token`: token compartilhado entre Core e Sales (se vazio, o Terraform gera e injeta nas tasks).
- `cognito_callback_urls` / `cognito_logout_urls`: listas de URLs autorizadas no User Pool Client.

> Os outputs retornam os DNS dos ALBs (Core e Sales), nomes dos serviços ECS, URLs dos ECRs e os identificadores do Cognito (User Pool, Client e domínio).

### Deploy automatizado com GitHub Actions

O workflow `.github/workflows/terraform.yml` executa:

- `terraform plan` em _pull requests_ para `main` (publicando o plano como artifact).
- `terraform plan` + `terraform apply` em pushes para `main`.
- Execução manual (`workflow_dispatch`), onde é possível forçar o apply marcando o input `apply_on_dispatch=true` ou destruir tudo (input `destroy=true`).

Configure os segredos/variáveis antes de habilitar o pipeline:

| Tipo     | Nome                      | Descrição                                                             |
|----------|---------------------------|------------------------------------------------------------------------|
| Secret   | `AWS_ACCESS_KEY_ID`       | Access key com permissão de aplicar o Terraform.                       |
| Secret   | `AWS_SECRET_ACCESS_KEY`   | Secret key correspondente.                                            |
| Secret   | `TF_BACKEND_BUCKET`       | Bucket S3 usado pelo backend remoto.                                  |
| Secret   | `TF_BACKEND_REGION`       | Região do bucket (ex.: `us-east-1`).                                   |
| Secret   | `TF_BACKEND_DYNAMO_TABLE` | (Opcional) tabela DynamoDB para lock do estado.                       |
| Secret   | `TF_STATE_KEY`            | Caminho/objeto do estado (`postech-car/terraform.tfstate`, por ex.).  |
| Variable | `AWS_REGION`              | (Opcional) Região default usada pelo provider e pelo workflow.        |

> Caso `TF_BACKEND_REGION` não seja informado, o workflow usa `AWS_REGION` (ou `us-east-1`). Sem `TF_BACKEND_DYNAMO_TABLE`, a etapa de lock remoto é ignorada.
