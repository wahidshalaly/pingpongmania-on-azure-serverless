using Microsoft.Extensions.Logging;

namespace PingPongMania.PlayFunctions;

public interface IPingClient
{
    Task InvokeAsync();
}

public class PingClient(IHttpClientFactory httpClientFactory, ILogger<PingClient> logger)
    : IPingClient
{
    public async Task InvokeAsync()
    {
        var ping = httpClientFactory.CreateClient("Ping");
        var response = await ping.GetAsync("api/ping");
        response.EnsureSuccessStatusCode();

        logger.LogInformation("Ping function has been called successfully.");
    }
}
