# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A sample solution demonstrating a serverless microservices chain on **.NET 10 Azure Functions**, with **.NET Aspire** for local development and **modular Bicep** for Azure provisioning. Layout: `functions/`, `aspire/`, `infra/`, `tests/` — see [README.md](README.md) for architecture and how to run it.

This code began life as a Dapr-on-Kubernetes experiment and was migrated here. That original stack (`src/`, `deploy/`, `skaffold.yaml`, `build/`, `.nuke/`, Nuke + Skaffold tooling) is **not** part of this repo — it's archived at [wahidshalaly/pingpongmania](https://github.com/wahidshalaly/pingpongmania), which is kept read-only for historical reference. Don't reintroduce Dapr, Kubernetes, Skaffold, or Nuke here.

## Hard constraints

- **Do not run `az deployment ... what-if` or `create`, create/modify Azure resources, or grant/change RBAC role assignments in a real Azure subscription, without the user's explicit, freshly-given permission for that specific action.** Bicep changes should be validated with `az bicep build` / `az bicep lint` only unless told otherwise. This applies even if an authenticated `az` CLI session happens to be available. Role assignment creation specifically requires the user to run it themselves or grant permission per-instance — see [infra/bootstrap/README.md](infra/bootstrap/README.md) for the OIDC deployment identity bootstrap, where this line was drawn in practice.
- Keep documentation (README.md, this file) updated in the same session as any change that affects setup steps, architecture, run commands, or repo layout — don't defer doc updates to a later cleanup pass.

## Build & test commands

```pwsh
# Build everything: the Aspire AppHost pulls in all 3 Functions projects + Shared + ServiceDefaults
dotnet build aspire/PingPongMania.AppHost/PingPongMania.AppHost.csproj

# Run locally — see README.md for how to find ports/call endpoints
cd aspire/PingPongMania.AppHost && dotnet run

# Unit tests
dotnet test tests/PingPongMania.Functions.Tests/PingPongMania.Functions.Tests.csproj

# Bicep validation only (no deploy)
az bicep build --file infra/main.bicep
az bicep lint --file infra/main.bicep

# Format check / apply
dotnet tool restore
dotnet csharpier check functions aspire tests
dotnet csharpier format functions aspire tests
```

Package versions are centrally managed via `Directory.Packages.props` at the repo root (NuGet Central Package Management) — don't add inline `Version=` attributes on `PackageReference` in any `.csproj`; add/bump the version in `Directory.Packages.props` instead.

## Conventions worth knowing

- All 3 Functions apps (`PongFunctions`, `PingFunctions`, `PlayFunctions`) are .NET 10 isolated-worker, each with a thin trigger class (`Ping`, `Play`, `Pong`, `RecordPing`) + an injectable `IXxxClient` interface for the HTTP call to the next service, to keep unit tests free of Functions-runtime fakery (see `tests/`).
- Aspire's `WithReference(...)` injects flat top-level config keys (`builder.Configuration["Key"]`), not `ConnectionStrings:Key` — code and `local.settings.json` follow that pattern.
- Use C# primary constructor syntax for dependency-injected classes (`public class Foo(IDep dep)`), not an explicit constructor body assigning to private readonly fields.
- Code style is enforced by [CSharpier](https://csharpier.com) (local dotnet tool, `.config/dotnet-tools.json`), scoped to `functions/`, `aspire/`, `tests/`. CI fails on unformatted code (`dotnet csharpier check`); run `dotnet csharpier format functions aspire tests` before committing. In VS Code, install the recommended `csharpier.csharpier-vscode` extension (prompted automatically via `.vscode/extensions.json`) — `.vscode/settings.json` sets it as the default C# formatter with format-on-save, and it auto-uses the version pinned in `.config/dotnet-tools.json`. CSharpier deliberately ignores `.editorconfig` (it's a non-configurable, opinionated formatter like Prettier), so no `.editorconfig` is needed for it.
- Bicep: a `module`'s `scope:` can only be resourceGroup/subscription/managementGroup/tenant, never an arbitrary existing-resource symbol. RBAC role assignments are declared as plain `resource` extension blocks in `infra/modules/rbac.bicep`, not as a generic nested module.
- `infra/main.bicep` is resource-group-scoped (`targetScope = 'resourceGroup'`) and assumes the resource group already exists — it does not create it. This is deliberate: it lets the CI deployment identity's RBAC stay scoped to just that one resource group instead of needing a subscription-wide role. The resource group itself is created once, manually, as part of the OIDC bootstrap — see [infra/bootstrap/README.md](infra/bootstrap/README.md).
