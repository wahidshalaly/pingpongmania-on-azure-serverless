var builder = DistributedApplication.CreateBuilder(args);

var storage = builder.AddAzureStorage("storage").RunAsEmulator();
var tables = storage.AddTables("tables");

var serviceBus = builder.AddAzureServiceBus("servicebus").RunAsEmulator();
var pingQueue = serviceBus.AddServiceBusQueue("ping-queue");

var pong = builder.AddAzureFunctionsProject<Projects.PongFunctions>("pongfunctions");

var ping = builder.AddAzureFunctionsProject<Projects.PingFunctions>("pingfunctions")
    .WithReference(tables, connectionName: "PingsTableConnection")
    .WithReference(pingQueue, connectionName: "ServiceBusConnection")
    .WaitFor(tables)
    .WaitFor(pingQueue)
    .WithEnvironment("PongBaseUrl", pong.GetEndpoint("http"));

var play = builder.AddAzureFunctionsProject<Projects.PlayFunctions>("playfunctions")
    .WithEnvironment("PingBaseUrl", ping.GetEndpoint("http"));

builder.Build().Run();
