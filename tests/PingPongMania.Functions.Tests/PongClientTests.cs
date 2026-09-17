using System.Net;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using PingPongMania.PingFunctions;

namespace PingPongMania.Functions.Tests;

public class PongClientTests
{
    private static (PongClient client, FakeHttpMessageHandler handler) CreateClient(HttpStatusCode statusCode)
    {
        var handler = new FakeHttpMessageHandler(statusCode);
        var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://localhost") };

        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(f => f.CreateClient("Pong")).Returns(httpClient);

        return (new PongClient(factory.Object, NullLogger<PongClient>.Instance), handler);
    }

    [Fact]
    public async Task InvokeAsync_CallsApiPong()
    {
        var (client, handler) = CreateClient(HttpStatusCode.OK);

        await client.InvokeAsync();

        Assert.NotNull(handler.LastRequest);
        Assert.EndsWith("/api/pong", handler.LastRequest!.RequestUri!.ToString());
    }

    [Fact]
    public async Task InvokeAsync_ThrowsWhenPongReturnsError()
    {
        var (client, _) = CreateClient(HttpStatusCode.InternalServerError);

        await Assert.ThrowsAsync<HttpRequestException>(() => client.InvokeAsync());
    }
}
