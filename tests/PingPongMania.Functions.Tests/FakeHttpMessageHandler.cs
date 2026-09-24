using System.Net;

namespace PingPongMania.Functions.Tests;

public class FakeHttpMessageHandler(HttpStatusCode statusCode) : HttpMessageHandler
{
    public HttpRequestMessage? LastRequest { get; private set; }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken
    )
    {
        LastRequest = request;
        return Task.FromResult(new HttpResponseMessage(statusCode));
    }
}
