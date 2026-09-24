using Microsoft.Extensions.Logging;

namespace PingPongMania.PingFunctions;

public interface IPongClient
{
    Task InvokeAsync();
}

public class PongClient(IHttpClientFactory httpClientFactory, ILogger<PongClient> logger)
    : IPongClient
{
    public async Task InvokeAsync()
    {
        var pong = httpClientFactory.CreateClient("Pong");
        var response = await pong.GetAsync("api/pong");
        response.EnsureSuccessStatusCode();

        logger.LogInformation("Pong function has been invoked successfully.");
    }
}
