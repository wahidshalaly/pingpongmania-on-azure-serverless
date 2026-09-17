using Azure;
using Azure.Data.Tables;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using PingPongMania.PingFunctions;

namespace PingPongMania.Functions.Tests;

public class PingStoreFunctionTests
{
    [Fact]
    public async Task Run_SavesMessageAndInvokesPong()
    {
        var tableClient = new Mock<TableClient>();
        tableClient
            .Setup(c => c.UpsertEntityAsync(It.IsAny<PingMessageEntity>(), It.IsAny<TableUpdateMode>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((Response)null!);

        var pongClient = new Mock<IPongClient>();
        pongClient.Setup(c => c.InvokeAsync()).Returns(Task.CompletedTask);

        var function = new PingStoreFunction(tableClient.Object, pongClient.Object, NullLogger<PingStoreFunction>.Instance);
        var message = new PingMessage(Guid.NewGuid(), DateTimeOffset.UtcNow);

        await function.Run(message);

        tableClient.Verify(
            c => c.UpsertEntityAsync(
                It.Is<PingMessageEntity>(e => e.RowKey == message.Id.ToString() && e.ReceivedAt == message.Timestamp),
                It.IsAny<TableUpdateMode>(),
                It.IsAny<CancellationToken>()),
            Times.Once);
        pongClient.Verify(c => c.InvokeAsync(), Times.Once);
    }

    [Fact]
    public async Task Run_DoesNotInvokePong_WhenTableWriteFails()
    {
        var tableClient = new Mock<TableClient>();
        tableClient
            .Setup(c => c.UpsertEntityAsync(It.IsAny<PingMessageEntity>(), It.IsAny<TableUpdateMode>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new RequestFailedException("storage unavailable"));

        var pongClient = new Mock<IPongClient>();
        var function = new PingStoreFunction(tableClient.Object, pongClient.Object, NullLogger<PingStoreFunction>.Instance);
        var message = new PingMessage(Guid.NewGuid(), DateTimeOffset.UtcNow);

        await Assert.ThrowsAsync<RequestFailedException>(() => function.Run(message));

        pongClient.Verify(c => c.InvokeAsync(), Times.Never);
    }
}
