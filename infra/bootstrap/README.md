# CI/CD bootstrap: OIDC deployment identity

This documents the one-time, manual setup that has to exist **before** any GitHub Actions workflow can deploy this repo's Bicep to Azure. It is not part of `main.bicep` and cannot be — see [Why this is manual, not Bicep](#why-this-is-manual-not-bicep) below.

## What gets created, per environment

1. A resource group (pre-created here with the exact name/tags `main.bicep` expects, so the pipeline's own deployment of it later is a no-op confirmation, not a conflict).
2. A **user-assigned managed identity** — no client secret ever exists; GitHub authenticates as it via OIDC token exchange.
3. Two **federated credentials** on that identity, trusting only this repo:
   - `push` to `main` (subject `repo:<owner>/<repo>:ref:refs/heads/main`)
   - `pull_request` (subject `repo:<owner>/<repo>:pull_request`) — lets PR workflows run `what-if` previews
4. Two RBAC role assignments on that identity, **both scoped only to the environment's resource group** — the identity never has any subscription-level permission:
   - **Contributor** — to deploy the actual resources. `main.bicep` is resource-group-scoped (`targetScope = 'resourceGroup'`); it assumes the resource group already exists (step 1, above) rather than creating it itself, specifically so the deploying identity never needs a subscription-wide grant just to run `az deployment group create`.
   - **Role Based Access Control Administrator** — needed only so `infra/modules/rbac.bicep` can assign its own roles (Storage/Service Bus data-plane access for the Function Apps' managed identities) during deployment.

> These identifiers (client ID, tenant ID, subscription ID) are **not secrets** — the trust boundary is the federated credential's subject match (this exact repo + branch/PR) and GitHub's OIDC token signing, not secrecy of these IDs. Microsoft's own guidance stores them as GitHub Actions **variables**, not **secrets**. Safe to keep in this file.

## Why this is manual, not Bicep

GitHub Actions needs a working identity *before* it can run a deployment. That identity, its federated credential, and its first role assignment must be created by someone who already has permissions (a human, via their own `az` session) — a pipeline cannot create the very identity it needs in order to authenticate. This is a one-time bootstrap per environment; everything *after* the identity exists (including all other RBAC in the app itself) is ordinary Bicep, run by the pipeline.

## Test environment — status

| Step | Status | Value |
|---|---|---|
| Resource group | ✅ created | `rg-pingpongmania-test` (`australiaeast`) |
| Managed identity | ✅ created | `id-pingpongmania-deploy-test` |
| — client ID | | `<client-id>` |
| — principal (object) ID | | `<principal-id>` |
| Federated credential (push main) | ✅ created | `gh-push-main` → `repo:wahidshalaly/pingpongmania:ref:refs/heads/main` |
| Federated credential (pull request) | ✅ created | `gh-pull-request` → `repo:wahidshalaly/pingpongmania:pull_request` |
| Role: Contributor @ test RG | ⏸ pending | scope `/subscriptions/<subscription-id>/resourceGroups/rg-pingpongmania-test` |
| Role: RBAC Administrator @ test RG | ⏸ pending | scope `/subscriptions/<subscription-id>/resourceGroups/rg-pingpongmania-test` |
| GitHub repo variables (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) | ⏸ pending | set after the roles above exist |
| `deploy-test.yml` workflow | ⏸ pending | Task 16, not yet authored |

Subscription: `<subscription-id>` ("<subscription-name>"). Tenant: `<tenant-id>` (<tenant-name>).

## Full command sequence (idempotent — safe to re-run)

```sh
SUB_ID="<subscription-id>"
RG="rg-pingpongmania-test"
IDENTITY="id-pingpongmania-deploy-test"
REPO="wahidshalaly/pingpongmania"

# 1. Resource group (already done)
az group create --name "$RG" --location australiaeast \
  --tags environment=test workload=pingpongmania managed-by=bicep

# 2. User-assigned managed identity (already done)
az identity create --name "$IDENTITY" --resource-group "$RG" --location australiaeast \
  --tags environment=test workload=pingpongmania managed-by=bicep purpose=github-actions-oidc

# 3. Federated credentials (already done)
az identity federated-credential create \
  --name gh-push-main --identity-name "$IDENTITY" --resource-group "$RG" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:${REPO}:ref:refs/heads/main" \
  --audiences "api://AzureADTokenExchange"

az identity federated-credential create \
  --name gh-pull-request --identity-name "$IDENTITY" --resource-group "$RG" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:${REPO}:pull_request" \
  --audiences "api://AzureADTokenExchange"

# 4. RBAC role assignments — PENDING, requires a human with sufficient rights to grant.
# Both scoped only to this one resource group -- the identity never gets subscription-level access.
PRINCIPAL_ID=$(az identity show --name "$IDENTITY" --resource-group "$RG" --query principalId -o tsv)

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role "Contributor" --scope "/subscriptions/$SUB_ID/resourceGroups/$RG"

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role "Role Based Access Control Administrator" --scope "/subscriptions/$SUB_ID/resourceGroups/$RG"

# 5. After the roles exist, publish the (non-secret) identifiers as GitHub repo variables
CLIENT_ID=$(az identity show --name "$IDENTITY" --resource-group "$RG" --query clientId -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

gh variable set AZURE_CLIENT_ID_TEST --body "$CLIENT_ID"
gh variable set AZURE_TENANT_ID --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID --body "$SUB_ID"
```

## Repeating for `prod` (Task 17)

Same shape, separate everything — never share an identity between `test` and `prod`:
- `rg-pingpongmania-prod`, `id-pingpongmania-deploy-prod`
- Federated credential subject likely scoped to a GitHub **Environment** (`environment:production`) rather than the `main` branch directly, so the existing GitHub Environment manual-approval gate also governs who can trigger a prod deployment.
- Separate `AZURE_CLIENT_ID_PROD` variable; `AZURE_TENANT_ID`/`AZURE_SUBSCRIPTION_ID` are shared (same tenant/subscription for this sample).

Not yet done — deferred to Task 17.
