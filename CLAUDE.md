# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Repo status: mid-migration

This repo is being modernized from Dapr-on-Kubernetes to .NET 10 Azure Functions + .NET Aspire (local dev) + Bicep (Azure provisioning). **Both stacks currently coexist:**

- **New (primary going forward)**: `functions/`, `aspire/`, `infra/`, `tests/` — see [README.md](README.md) for architecture and how to run it.
- **Legacy (being retired, do not delete yet)**: `src/`, `deploy/`, `skaffold.yaml`, `build/`, `.nuke/`, `build.{cmd,sh,ps1}` — the original Dapr/Kubernetes implementation. Keep this working and do not remove it until the new serverless path has been proven with a real Azure deployment (a live end-to-end smoke test through a deployed APIM endpoint). This is intentional — don't "clean up" the legacy stack as an unrelated tidy-up.

## Hard constraints

- **Do not run `az deployment ... what-if` or `create`, or otherwise provision/modify resources in a real Azure subscription, without the user's explicit, freshly-given permission for that specific action.** Bicep changes should be validated with `az bicep build` / `az bicep lint` only unless told otherwise. This applies even if an authenticated `az` CLI session happens to be available.
- Keep documentation (README.md, this file) updated in the same session as any change that affects setup steps, architecture, run commands, or repo layout — don't defer doc updates to a later cleanup pass.

## Build & test commands

```pwsh
# Legacy Dapr/K8s solution
dotnet build src/PingPongMania.sln

# New stack: Aspire AppHost (pulls in all 3 Functions projects + Shared + ServiceDefaults)
dotnet build aspire/PingPongMania.AppHost/PingPongMania.AppHost.csproj

# Run locally (new stack) — see README.md for how to find ports/call endpoints
cd aspire/PingPongMania.AppHost && dotnet run

# Unit tests (new stack)
dotnet test tests/PingPongMania.Functions.Tests/PingPongMania.Functions.Tests.csproj

# Bicep validation only (no deploy)
az bicep build --file infra/main.bicep
az bicep lint --file infra/main.bicep
```

Package versions are centrally managed via `Directory.Packages.props` at the repo root (NuGet Central Package Management) — don't add inline `Version=` attributes on `PackageReference` in any `.csproj`; add/bump the version in `Directory.Packages.props` instead.

## Conventions worth knowing

- All 3 Functions apps (`PongFunctions`, `PingFunctions`, `PlayFunctions`) are .NET 10 isolated-worker, each with a thin trigger + an injectable `IXxxClient` interface for the HTTP call to the next service, to keep unit tests free of Functions-runtime fakery (see `tests/`).
- Aspire's `WithReference(...)` injects flat top-level config keys (`builder.Configuration["Key"]`), not `ConnectionStrings:Key` — code and `local.settings.json` follow that pattern.
- Bicep: a `module`'s `scope:` can only be resourceGroup/subscription/managementGroup/tenant, never an arbitrary existing-resource symbol. RBAC role assignments are declared as plain `resource` extension blocks in `infra/modules/rbac.bicep`, not as a generic nested module.
