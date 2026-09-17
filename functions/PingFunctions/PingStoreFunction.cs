using Azure.Data.Tables;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using static PingPongMania.Constants;

namespace PingPongMania.PingFunctions;

public class PingStoreFunction
{
    private readonly TableClient _tableClient;
    private readonly IPongClient _pongClient;
    private readonly ILogger<PingStoreFunction> _logger;

    public PingStoreFunction(TableClient tableClient, IPongClient pongClient, ILogger<PingStoreFunction> logger)
    {
        _tableClient = tableClient;
        _pongClient = pongClient;
        _logger = logger;
    }

    [Function("PingStore")]
    public async Task Run([ServiceBusTrigger(PingQueueName, Connection = "ServiceBusConnection")] PingMessage message)
    {
        await _tableClient.UpsertEntityAsync(PingMessageEntity.FromMessage(message));
        _logger.LogInformation("Ping message Id: [{Id}], Timestamp: [{Timestamp}] has been saved.", message.Id, message.Timestamp);

        await _pongClient.InvokeAsync();
    }
}
