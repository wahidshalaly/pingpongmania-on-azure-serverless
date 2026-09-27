# CI/CD bootstrap: OIDC deployment identity

This documents the one-time, manual setup that has to exist **before** any GitHub Actions workflow can deploy this repo's Bicep to Azure. It is not part of `main.bicep` and cannot be — see [Why this is manual, not Bicep](#why-this-is-manual-not-bicep) below.

> **This is a public repo — no real tenant, subscription, or identity IDs belong in this file.** They aren't credentials (see [What is and isn't sensitive here](#what-is-and-isnt-sensitive-here)), but publishing them is free reconnaissance for anyone targeting the tenant. Every command below reads the values it needs from `az` at runtime instead of hardcoding them.

## What gets created, per environment

1. A resource group (pre-created with the exact name/tags `main.bicep` expects, so the pipeline's own deployment of it later is a no-op confirmation, not a conflict).
2. A **user-assigned managed identity** — no client secret ever exists; GitHub authenticates as it via OIDC token exchange.
3. A **federated credential** on that identity, trusting only this repo's `main` branch (subject `repo:<owner>/<repo>:ref:refs/heads/main`). See [the open item below](#-open-item-the-pull_request-federated-credential) about a second, `pull_request`-scoped credential that exists and should be deleted.
4. Two RBAC role assignments on that identity, **both scoped only to the environment's resource group** — the identity never has any subscription-level permission:
   - **Contributor** — to deploy the actual resources. `main.bicep` is resource-group-scoped (`targetScope = 'resourceGroup'`); it assumes the resource group already exists (step 1) rather than creating it itself, specifically so the deploying identity never needs a subscription-wide grant just to run `az deployment group create`.
   - **Role Based Access Control Administrator** — needed only so `infra/modules/rbac.bicep` can assign its own roles (Storage/Service Bus data-plane access for the Function Apps' managed identities) during deployment.

## What is and isn't sensitive here

| Value | Sensitive? | Notes |
|---|---|---|
| Client ID, tenant ID, subscription ID, principal ID | Not credentials, but **don't publish them** | Holding them grants no access — the trust boundary is the federated credential's subject match plus GitHub's signed OIDC token. But they aid tenant enumeration and targeted phishing, so they stay out of this public repo. |
| These same values as GitHub Actions **variables** | Appropriate | Readable only by repo collaborators. Microsoft's `azure/login` guidance stores them as variables, not secrets. This is *not* a licence to commit them to a public file — different threat model. |
| Anything that authenticates | Never in the repo | With OIDC there is no client secret to leak at all, which is the main reason to prefer a managed identity + federated credential over an app registration with a secret. |

## Why this is manual, not Bicep

GitHub Actions needs a working identity *before* it can run a deployment. That identity, its federated credential, and its first role assignment must be created by someone who already has permissions (a human, via their own `az` session) — a pipeline cannot create the very identity it needs in order to authenticate. This is a one-time bootstrap per environment; everything *after* the identity exists (including all other RBAC in the app itself) is ordinary Bicep, run by the pipeline.

## Test environment — status

| Step | Status | Notes |
|---|---|---|
| Resource group | ✅ created | `rg-pingpongmania-test` (`australiaeast`) |
| Managed identity | ✅ created | `id-pingpongmania-deploy-test` |
| Federated credential (push `main`) | ✅ created | `gh-push-main` |
| Federated credential (`pull_request`) | ⚠️ exists, should be deleted | see [open item](#-open-item-the-pull_request-federated-credential) |
| Role: Contributor @ test RG | ✅ created | resource-group scope only |
| Role: RBAC Administrator @ test RG | ✅ created | resource-group scope only |
| GitHub repo variables | ✅ set | `AZURE_CLIENT_ID_TEST`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| `deploy-test.yml` workflow | ⏸ pending | Task 16, not yet authored |
| First `what-if` / deploy | ⏸ pending | not yet run against the live subscription |

To see the current values for this environment:

```sh
az identity show --name id-pingpongmania-deploy-test --resource-group rg-pingpongmania-test \
  --query "{clientId:clientId, principalId:principalId}" -o table
az identity federated-credential list --identity-name id-pingpongmania-deploy-test \
  --resource-group rg-pingpongmania-test --query "[].{name:name, subject:subject}" -o table
az role assignment list --assignee "$(az identity show --name id-pingpongmania-deploy-test \
  --resource-group rg-pingpongmania-test --query principalId -o tsv)" --all \
  --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

## Full command sequence (idempotent — safe to re-run)

Run against the intended subscription; nothing here is hardcoded to a specific tenant or subscription.

```sh
ENV_NAME="test"
LOCATION="australiaeast"
RG="rg-pingpongmania-${ENV_NAME}"
IDENTITY="id-pingpongmania-deploy-${ENV_NAME}"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
SUB_ID="$(az account show --query id -o tsv)"

# 1. Resource group
az group create --name "$RG" --location "$LOCATION" \
  --tags environment="$ENV_NAME" workload=pingpongmania managed-by=bicep

# 2. User-assigned managed identity
az identity create --name "$IDENTITY" --resource-group "$RG" --location "$LOCATION" \
  --tags environment="$ENV_NAME" workload=pingpongmania managed-by=bicep purpose=github-actions-oidc

# 3. Federated credential for deployments from main
az identity federated-credential create \
  --name gh-push-main --identity-name "$IDENTITY" --resource-group "$RG" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:${REPO}:ref:refs/heads/main" \
  --audiences "api://AzureADTokenExchange"

# 4. RBAC role assignments -- requires a human with rights to grant them.
# Both scoped only to this one resource group; the identity never gets subscription-level access.
# --assignee-object-id (not --assignee) avoids the Graph lookup, which can fail on a
# just-created identity that hasn't replicated yet.
PRINCIPAL_ID="$(az identity show --name "$IDENTITY" --resource-group "$RG" --query principalId -o tsv)"

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role "Contributor" --scope "/subscriptions/$SUB_ID/resourceGroups/$RG"

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role "Role Based Access Control Administrator" --scope "/subscriptions/$SUB_ID/resourceGroups/$RG"

# 5. Publish the identifiers the workflow needs as GitHub repo variables (not secrets)
gh variable set "AZURE_CLIENT_ID_$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')" \
  --body "$(az identity show --name "$IDENTITY" --resource-group "$RG" --query clientId -o tsv)"
gh variable set AZURE_TENANT_ID --body "$(az account show --query tenantId -o tsv)"
gh variable set AZURE_SUBSCRIPTION_ID --body "$SUB_ID"
```

## ⚠️ Open item: the `pull_request` federated credential

This bootstrap also created a credential with subject `repo:<owner>/<repo>:pull_request`, to let PR workflows run `what-if` previews. **It still exists and should be removed** — on a **public** repo it's a footgun. GitHub withholds `id-token` from fork-triggered `pull_request` runs, so it isn't directly exploitable today, but it means any later workflow change (switching to `pull_request_target`, or a PR-triggered job that executes PR-authored code) could hand an outsider a token with Contributor on the resource group.

Recommended: delete it and trigger `what-if` from `workflow_dispatch` instead, where only people with write access can run it.

```sh
az identity federated-credential delete --name gh-pull-request \
  --identity-name id-pingpongmania-deploy-test --resource-group rg-pingpongmania-test --yes
```

## Repeating for `prod`

Same shape, separate everything — never share an identity between `test` and `prod`:
- `rg-pingpongmania-prod`, `id-pingpongmania-deploy-prod`
- Federated credential subject scoped to a GitHub **Environment** (`repo:<owner>/<repo>:environment:production`) rather than the `main` branch, so the Environment's manual-approval gate also governs who can trigger a prod deployment.
- Separate `AZURE_CLIENT_ID_PROD` variable; `AZURE_TENANT_ID`/`AZURE_SUBSCRIPTION_ID` are shared.

Not done — the Bicep supports `prod` via `infra/environments/prod.bicepparam`, but deploying it is deferred until there's a reason to.
