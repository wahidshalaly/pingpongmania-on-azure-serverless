using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace PingPongMania.PlayFunctions;

public class PlayFunction
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<PlayFunction> _logger;

    public PlayFunction(IHttpClientFactory httpClientFactory, ILogger<PlayFunction> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    [Function("Play")]
    public async Task<IActionResult> Get([HttpTrigger(AuthorizationLevel.Function, "get", Route = "play")] HttpRequest req)
    {
        _logger.LogInformation("Play function has been invoked.");

        try
        {
            var ping = _httpClientFactory.CreateClient("Ping");
            var response = await ping.GetAsync("api/ping");
            response.EnsureSuccessStatusCode();

            _logger.LogInformation("Ping function has been called successfully.");
            return new OkResult();
        }
        catch (Exception exception)
        {
            const string errorMessage = "Failed to call Ping function.";
            _logger.LogError(exception, errorMessage);
            return new ObjectResult(errorMessage) { StatusCode = StatusCodes.Status500InternalServerError };
        }
    }
}
