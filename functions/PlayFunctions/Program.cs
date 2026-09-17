using Azure.Monitor.OpenTelemetry.Exporter;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Azure.Functions.Worker.OpenTelemetry;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OpenTelemetry;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();
builder.AddServiceDefaults();

builder.Services.AddHttpClient("Ping", client =>
{
    var pingBaseUrl = builder.Configuration["PingBaseUrl"] ?? "http://localhost:7072";
    client.BaseAddress = new Uri(pingBaseUrl);
});

var openTelemetryBuilder = builder.Services.AddOpenTelemetry()
    .UseFunctionsWorkerDefaults();

if (!string.IsNullOrEmpty(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
    openTelemetryBuilder.UseAzureMonitorExporter();

builder.Build().Run();
