using Azure;
using Azure.Data.Tables;

namespace PingPongMania.PingFunctions;

public class PingMessageEntity : ITableEntity
{
    public string PartitionKey { get; set; } = "ping";
    public string RowKey { get; set; } = default!;
    public DateTimeOffset? Timestamp { get; set; }
    public ETag ETag { get; set; }

    public DateTimeOffset ReceivedAt { get; set; }

    public static PingMessageEntity FromMessage(PingMessage message) => new()
    {
        RowKey = message.Id.ToString(),
        ReceivedAt = message.Timestamp
    };
}
