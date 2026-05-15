# Azure Zero Trust Identity Pipeline

A production-grade identity security pipeline built on Azure that enforces Zero Trust principles across authentication, privileged access, workload identity, and threat detection. Deployed across 7 phases using Terraform and Azure CLI.

## Architecture

```
Microsoft Entra ID (Identity Plane)
  Users · Groups · App Registration · Managed Identity

Workload Security
  Key Vault (RBAC · secrets · audit logs)
  Storage Account (OAuth only · no shared keys)
  GitHub Actions (federated OIDC credential · no stored secrets)

Threat Detection
  Defender for Cloud (Key Vault · Storage · ARM · Standard tier)
  Log Analytics Workspace (central log store)
  Microsoft Sentinel (5 MITRE ATT&CK mapped analytics rules)

Response & Alerting
  Logic App (incident playbook · webhook notification)
  Azure Monitor (4 activity log alerts)
  Action Group (email · webhook)
```

## Design Decisions

**RBAC over legacy access policies.** Every resource in this pipeline uses Azure role-based access control. Key Vault has no access policies. Storage has no shared keys. This enforces the principle of least privilege at the data plane level, not just the control plane.

**Managed identity over service principal secrets.** The demo workload uses a user-assigned managed identity with a scoped Storage Blob Data Reader role assignment. No credentials are stored anywhere in the pipeline.

**Federated identity for CI.** The app registration carries an OIDC federated credential for GitHub Actions. The CI pipeline authenticates via token exchange, eliminating the rotation problem for static secrets in repositories.

**CLI for what Terraform cannot own.** PIM eligible role assignments and Sentinel data connectors sit outside Terraform state and are managed via `scripts/bootstrap.sh`. This is a deliberate architectural decision, not a gap. Resources that require P2 licensing or Defender portal enrollment on personal tenants are documented rather than forced.

**Separate teardown lifecycle.** `scripts/teardown.sh` handles resource ordering that Terraform destroy gets wrong: Sentinel connectors and automation rules before the workspace, Key Vault purge before reprovisioning, PIM cleanup before role assignments.

## Modules

| Module | Resources | Phase |
|---|---|---|
| `entra_identity` | Users, groups, app registration, managed identity, storage account, RBAC | 1 |
| `conditional_access` | Named locations, 5 CA policies (report-only, requires Entra P1) | 2 |
| `key_vault` | Key Vault, OIDC federated credential, Log Analytics workspace, diagnostic settings | 3 |
| `defender` | Defender plans (Key Vault, Storage, ARM), security contact, LAW export | 4 |
| `sentinel` | Sentinel onboarding, 5 scheduled analytics rules | 5 |
| `playbooks` | Logic App workflow, HTTP trigger, webhook action | 6 |
| `monitoring` | Action group, metric alert, 4 activity log alerts | 7 |

## Analytics Rules (MITRE ATT&CK)

| Rule | Tactic | Technique |
|---|---|---|
| Multiple failed sign-ins | Credential Access | T1110 |
| Sign-in from new country | Initial Access | T1078 |
| PIM activation outside business hours | Privilege Escalation | T1078 |
| Key Vault access from unfamiliar IP | Credential Access | T1552 |
| Bulk user deletion | Impact | T1531 |

## Tenant Limitations (Personal Account)

This project was built on a personal Azure subscription. The following features are documented in code but require Entra ID P1/P2 to enforce:

**Conditional Access enforcement.** The `conditional_access` module defines 5 policies covering MFA, legacy auth blocking, device compliance, and risk-based sign-in controls. These are set to `enabledForReportingButNotEnforced` on a personal tenant. Activation requires P1.

**PIM eligible role assignments.** The `pim-assignments.json` template and `bootstrap.sh` PIM section are written for production use. Eligible role activation requires P2.

**Sentinel automation rule.** The Logic App playbook uses an HTTP trigger. Connecting it to Sentinel incident creation via an automation rule requires the Microsoft Sentinel Logic Apps connector, which is managed through the Defender portal on personal tenants.

All code is production-ready. These are licensing constraints, not architectural gaps.

## Prerequisites

- Azure subscription with Owner role
- Entra ID Global Administrator or Privileged Role Administrator
- App registration with Microsoft Graph application permissions admin-consented
- AWS S3 bucket for Terraform state (`tf-backend-jord-projs`)
- GitHub repository for OIDC federated credential

### Required Graph Permissions

```
Application.ReadWrite.All
Directory.ReadWrite.All
Group.ReadWrite.All
Policy.ReadWrite.ConditionalAccess
RoleManagement.ReadWrite.Directory
User.ReadWrite.All
```

### Provider Registrations

```bash
az provider register --namespace Microsoft.SecurityInsights
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Security
az provider register --namespace Microsoft.Logic
```

## Deployment

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform plan
terraform apply -auto-approve
source .env
RESOURCE_GROUP=zero-trust-identity-rg WORKSPACE_NAME=zt-identity-law ./scripts/bootstrap.sh
```

## Teardown

```bash
RESOURCE_GROUP=zero-trust-identity-rg WORKSPACE_NAME=zt-identity-law ./scripts/teardown.sh
```

## Stack

Terraform · Azure CLI · Microsoft Entra ID · Azure Key Vault · Azure Storage · Microsoft Sentinel · Defender for Cloud · Log Analytics · Azure Monitor · Azure Logic Apps · GitHub Actions OIDC

## Related Projects

- [LLM Gateway and Observability Platform](https://github.com/jordann6/llm-gateway) - FastAPI on ECS Fargate, multi-provider LLM routing, DynamoDB caching, CloudWatch observability
- [Cloud Security Lab](https://github.com/jordann6/cloud-security-lab) - Full AWS and Kubernetes threat detection, Pacu attack chain, Falco, OpenSearch SIEM, MITRE ATT&CK kill chain
