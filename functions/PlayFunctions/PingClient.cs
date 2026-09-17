using Microsoft.Extensions.Logging;

namespace PingPongMania.PlayFunctions;

public interface IPingClient
{
    Task InvokeAsync();
}

public class PingClient : IPingClient
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<PingClient> _logger;

    public PingClient(IHttpClientFactory httpClientFactory, ILogger<PingClient> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public async Task InvokeAsync()
    {
        var ping = _httpClientFactory.CreateClient("Ping");
        var response = await ping.GetAsync("api/ping");
        response.EnsureSuccessStatusCode();

        _logger.LogInformation("Ping function has been called successfully.");
    }
}
