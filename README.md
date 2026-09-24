# PingPongMania

A small sample solution demonstrating a serverless microservices chain on **Azure Functions**, **.NET 10**, and **.NET Aspire** for local development, provisioned with **modular Bicep** IaC.

The scenario is intentionally trivial: three services — **Play**, **Ping**, and **Pong** — each expose a single endpoint. `Play` calls `Ping`, and `Ping` calls `Pong`, either directly over HTTP or via an asynchronous queue (Service Bus), with `Ping` also persisting a record of each call to table storage.

> **Repo status**: this project is mid-migration from an earlier Dapr/Kubernetes-based implementation to the serverless architecture described below. The new path (this document) is fully built, tested, and ready to run locally; live Azure deployment automation is still being added. The legacy stack still lives under [src/](src/), [deploy/](deploy/), and [skaffold.yaml](skaffold.yaml) and will be removed once the new path is proven in a real Azure deployment — see [Legacy Dapr/Kubernetes stack](#legacy-daprkubernetes-stack-being-retired) below.

## Architecture

| Concern | Technology |
|---|---|
| Compute | 3 Azure Functions apps (.NET 10, isolated worker), Flex Consumption plan |
| Orchestration (Azure) | Logic App (Consumption) — models the Play → Ping → Pong chain, branching between an HTTP call and a Service Bus send |
| Front door (Azure) | API Management (Consumption tier), subscription-key protected |
| Messaging | Azure Service Bus queue (`ping-queue`) |
| State | Azure Table Storage (`pings` table) |
| Identity | System-assigned managed identity + RBAC everywhere possible (no connection strings, except one Function key used by the Logic App) |
| Observability | Application Insights + Log Analytics, shared across resources |
| Local dev | .NET Aspire (AppHost + ServiceDefaults), orchestrating the 3 Functions projects plus Azurite and a Service Bus emulator in Docker |
| IaC | Modular Bicep (Azure Verified Modules where available), one parameter file per environment (`test`, `prod`) |

```
Play  -->  Ping  -->  Pong
              \-> Table Storage (pings)
```

In Azure, `Play`'s public entry point is APIM → a Logic App workflow, which either calls `Ping` directly over HTTP or drops a message on `ping-queue` (consumed by `Ping`'s Service Bus-triggered function). Locally, `Play` calls `Ping` directly over HTTP — the queue path is exercised by publishing to the emulated queue directly (see [Testing the Service Bus path](#testing-the-service-bus-path-locally)).

### Repo layout

```
functions/
  PlayFunctions/     Play      — api/play, HTTP trigger, calls Ping
  PingFunctions/     Ping      — api/ping, HTTP trigger, calls Pong
                     RecordPing — Service Bus trigger, writes to Table Storage, then calls Pong
  PongFunctions/     Pong      — api/pong, HTTP trigger, trivial 200 OK
  Shared/            PingMessage record + queue/table name constants

aspire/
  PingPongMania.AppHost/        local orchestrator: wires the 3 Functions + Azurite + Service Bus emulator
  PingPongMania.ServiceDefaults/  OpenTelemetry, health checks, service discovery

infra/
  main.bicep                    resource-group-scoped orchestrator (assumes the RG already exists)
  modules/                      one file per resource type (Storage, Service Bus, Function App, Logic App, APIM, RBAC, ...)
  environments/                 test.bicepparam, prod.bicepparam
  bootstrap/                    manual, one-time OIDC deployment identity setup (per environment)

tests/
  PingPongMania.Functions.Tests/  xUnit + Moq unit tests for all 3 Functions apps
```

## Running locally

**Prerequisites**: [.NET 10 SDK](https://dotnet.microsoft.com/download), [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local) v4, [Docker](https://www.docker.com/) (for the Azurite and Service Bus emulators). The [Aspire CLI](https://learn.microsoft.com/dotnet/aspire/cli/overview) is bundled automatically via the AppHost's tooling — no separate install needed.

```pwsh
cd aspire/PingPongMania.AppHost
dotnet run
```

This starts all three Functions apps plus the local Azurite and Service Bus emulator containers, and prints an **Aspire dashboard** URL to the console, e.g.:

```
   Dashboard:  https://localhost:17131/login?t=<token>
```

Open it in a browser (the token logs you in automatically). The **Resources** page lists each Function app — `playfunctions`, `pingfunctions`, `pongfunctions` — with its actual local endpoint URL. Ports are assigned dynamically per run, so always get the current URL from the dashboard rather than assuming a fixed port.

### Calling the endpoints

Click a Function's endpoint in the dashboard, or copy the URL and call it directly:

```
GET /api/play    — exercises the full chain: Play → Ping → Pong
GET /api/ping    — Ping → Pong only
GET /api/pong    — trivial 200 OK
```

```pwsh
curl https://localhost:<play-port>/api/play
```

A `200` response means the whole chain succeeded. Each HTTP trigger is declared with `AuthorizationLevel.Function` in code, but local `dotnet run`/Functions Core Tools development does **not** enforce that — no function key is needed when calling these endpoints locally. A real Azure deployment does require a key (or, in practice, goes through APIM/the Logic App instead of calling the Function directly).

### Testing the Service Bus path locally

`RecordPing` (the queue-triggered half of the `PingFunctions` app) only fires on messages published to `ping-queue`. There's no local HTTP trigger for this path — that branching lives in the Logic App workflow (Azure-only, not part of local Aspire orchestration). To exercise it locally, publish a `PingMessage`-shaped JSON payload to the emulated queue directly (e.g. via the Service Bus SDK or a tool like Service Bus Explorer), using the emulator's connection string shown in the dashboard's `servicebus` resource.

## Running tests

```pwsh
dotnet test tests/PingPongMania.Functions.Tests/PingPongMania.Functions.Tests.csproj
```

## Infrastructure as Code

The Bicep templates under [infra/](infra/) are structurally validated (`az bicep build` / `az bicep lint` clean for `main.bicep` and both `.bicepparam` files) but have **not yet been deployed** to a real subscription — `what-if`/deploy automation (CI/CD) is still in progress. `main.bicep` is resource-group-scoped (it assumes the resource group already exists — see [infra/bootstrap/README.md](infra/bootstrap/README.md) — rather than creating it itself, so the deploying identity never needs subscription-level permissions). To validate locally:

```pwsh
az bicep build --file infra/main.bicep
az deployment group what-if --resource-group rg-pingpongmania-test --template-file infra/main.bicep --parameters infra/environments/test.bicepparam
```

## CI/CD

[.github/workflows/build-test.yml](.github/workflows/build-test.yml) checks code formatting (`functions/`, `aspire/`, `tests/`), builds the legacy `src/` solution, builds the Aspire AppHost (which pulls in all 3 Functions projects), and runs the test suite on every push/PR to `main`. Deployment workflows (OIDC-based `az deployment` to `test`/`prod`) are not yet added — the one-time manual bootstrap they depend on (an OIDC deployment identity per environment) is in progress; see [infra/bootstrap/README.md](infra/bootstrap/README.md).

Code style for the new stack is enforced by [CSharpier](https://csharpier.com):
```pwsh
dotnet tool restore
dotnet csharpier format functions aspire tests
```

## Legacy Dapr/Kubernetes stack (being retired)

[src/](src/), [deploy/](deploy/), [skaffold.yaml](skaffold.yaml), [build/](build/), and [.nuke/](.nuke/) contain the original implementation of this sample: the same Play/Ping/Pong scenario built on **Dapr** running on **Kubernetes**, deployed with **Skaffold**, built with **Nuke**. It still builds and runs but is no longer the primary path for this repo and will be deleted once the serverless architecture above has been proven with a real Azure deployment.

<details>
<summary>Running the legacy stack (click to expand)</summary>

You may set up a local Kubernetes cluster on Minikube, or use Azure Kubernetes Service instead to free your laptop's resources.
- Install Minikube from [minikube](https://minikube.sigs.k8s.io/docs/start/)
- Enable the Minikube `ingress` addon
- Install Dapr to the local cluster: `dapr init -k`
- Use Skaffold to deploy to the cluster: `skaffold dev`

### Skaffold initiation
Required only once before first use:
```
skaffold init --generate-manifests
```
Select to build images using Dockerfile. You'll need to make minor modifications to the generated manifests to suit your architecture.

### Build, deploy, and watch
If you're not using a local cluster, you'll need a container registry (e.g. Azure Container Registry) and must set the default repository:
```pwsh
$env:SKAFFOLD_DEFAULT_REPO='wshalalylab.azurecr.io/pingpongmania'
```
Then use Skaffold's development mode to watch for file changes and automatically build/deploy:
```
skaffold dev
```
To run once without watching:
```
skaffold run --cleanup --tail
```
To clean up:
```
skaffold delete
```

### Secrets
The legacy stack uses Kubernetes secrets, created outside of the Skaffold process. If testing Pub/Sub service invocation, you'll need connection strings for Azure Service Bus and Azure Table Storage, written to text files and imported via `kubectl`:
```
kubectl create secret generic storage-account-key --from-file=storageAccountName=..\azurestorage-accountkey.txt -n pingpongmania-dev
kubectl create secret generic asb-connection-string --from-file=connectionString=..\servicebus-connectionstring.txt -n pingpongmania-dev
```

### Tips
- Use [HTTPie](https://httpie.io) for quick API testing: `http GET http://localhost:5000/api/ping`
- To fix the NuGet missing package error `NETSDK1064`, ensure a `.dockerignore` file exists at the root of the Docker build context. See [Microsoft's guidance](https://docs.microsoft.com/en-us/dotnet/core/tools/sdk-errors/netsdk1064) and this [Stack Overflow thread](https://stackoverflow.com/questions/61167032/error-netsdk1064-package-dnsclient-1-2-0-was-not-found).

</details>
