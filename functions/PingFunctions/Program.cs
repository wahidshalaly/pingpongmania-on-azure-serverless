using Azure.Data.Tables;
using Azure.Identity;
using Azure.Monitor.OpenTelemetry.Exporter;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Azure.Functions.Worker.OpenTelemetry;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OpenTelemetry;
using PingPongMania.PingFunctions;
using static PingPongMania.Constants;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();
builder.AddServiceDefaults();

builder.Services.AddHttpClient("Pong", client =>
{
    var pongBaseUrl = builder.Configuration["PongBaseUrl"] ?? "http://localhost:7071";
    client.BaseAddress = new Uri(pongBaseUrl);
});
builder.Services.AddScoped<PongClient>();

builder.Services.AddSingleton(_ =>
{
    // In Azure, the storage account has shared-key access disabled, so the deployed app
    // connects via its managed identity using a service URI. Locally (Aspire or solo dev
    // against Azurite), a plain connection string is used instead.
    var tableServiceUri = builder.Configuration["PingsTableConnection__tableServiceUri"];
    var tableClient = !string.IsNullOrEmpty(tableServiceUri)
        ? new TableClient(new Uri(tableServiceUri), PingTableName, new DefaultAzureCredential())
        : new TableClient(builder.Configuration["PingsTableConnection"] ?? "UseDevelopmentStorage=true", PingTableName);
    tableClient.CreateIfNotExists();
    return tableClient;
});

var openTelemetryBuilder = builder.Services.AddOpenTelemetry()
    .UseFunctionsWorkerDefaults();

if (!string.IsNullOrEmpty(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
    openTelemetryBuilder.UseAzureMonitorExporter();

builder.Build().Run();
