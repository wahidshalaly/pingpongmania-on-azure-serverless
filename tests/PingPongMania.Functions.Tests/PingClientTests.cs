using System.Net;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using PingPongMania.PlayFunctions;

namespace PingPongMania.Functions.Tests;

public class PingClientTests
{
    private static (PingClient client, FakeHttpMessageHandler handler) CreateClient(
        HttpStatusCode statusCode
    )
    {
        var handler = new FakeHttpMessageHandler(statusCode);
        var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://localhost") };

        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(f => f.CreateClient("Ping")).Returns(httpClient);

        return (new PingClient(factory.Object, NullLogger<PingClient>.Instance), handler);
    }

    [Fact]
    public async Task InvokeAsync_CallsApiPing()
    {
        var (client, handler) = CreateClient(HttpStatusCode.OK);

        await client.InvokeAsync();

        Assert.NotNull(handler.LastRequest);
        Assert.EndsWith("/api/ping", handler.LastRequest!.RequestUri!.ToString());
    }

    [Fact]
    public async Task InvokeAsync_ThrowsWhenPingReturnsError()
    {
        var (client, _) = CreateClient(HttpStatusCode.InternalServerError);

        await Assert.ThrowsAsync<HttpRequestException>(() => client.InvokeAsync());
    }
}
