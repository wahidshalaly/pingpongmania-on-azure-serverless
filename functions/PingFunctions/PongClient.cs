using Microsoft.Extensions.Logging;

namespace PingPongMania.PingFunctions;

public interface IPongClient
{
    Task InvokeAsync();
}

public class PongClient : IPongClient
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<PongClient> _logger;

    public PongClient(IHttpClientFactory httpClientFactory, ILogger<PongClient> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public async Task InvokeAsync()
    {
        var pong = _httpClientFactory.CreateClient("Pong");
        var response = await pong.GetAsync("api/pong");
        response.EnsureSuccessStatusCode();

        _logger.LogInformation("Pong function has been invoked successfully.");
    }
}
