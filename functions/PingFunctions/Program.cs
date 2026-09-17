using Azure.Data.Tables;
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
    var connectionString = builder.Configuration["PingsTableConnection"] ?? "UseDevelopmentStorage=true";
    var tableClient = new TableClient(connectionString, PingTableName);
    tableClient.CreateIfNotExists();
    return tableClient;
});

var openTelemetryBuilder = builder.Services.AddOpenTelemetry()
    .UseFunctionsWorkerDefaults();

if (!string.IsNullOrEmpty(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
    openTelemetryBuilder.UseAzureMonitorExporter();

builder.Build().Run();
