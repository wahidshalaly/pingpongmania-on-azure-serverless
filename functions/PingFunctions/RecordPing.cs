using Azure.Data.Tables;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using static PingPongMania.Constants;

namespace PingPongMania.PingFunctions;

public class RecordPing(TableClient tableClient, IPongClient pongClient, ILogger<RecordPing> logger)
{
    [Function("RecordPing")]
    public async Task Run(
        [ServiceBusTrigger(PingQueueName, Connection = "ServiceBusConnection")] PingMessage message
    )
    {
        await tableClient.UpsertEntityAsync(PingMessageEntity.FromMessage(message));
        logger.LogInformation(
            "Ping message Id: [{Id}], Timestamp: [{Timestamp}] has been saved.",
            message.Id,
            message.Timestamp
        );

        await pongClient.InvokeAsync();
    }
}
