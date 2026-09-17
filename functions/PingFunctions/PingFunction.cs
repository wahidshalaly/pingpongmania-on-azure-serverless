using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace PingPongMania.PingFunctions;

public class PingFunction
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<PingFunction> _logger;

    public PingFunction(IHttpClientFactory httpClientFactory, ILogger<PingFunction> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    [Function("Ping")]
    public async Task<IActionResult> Reply([HttpTrigger(AuthorizationLevel.Function, "get", Route = "ping")] HttpRequest req)
    {
        _logger.LogInformation("Ping function has been invoked.");

        try
        {
            var pong = _httpClientFactory.CreateClient("Pong");
            var response = await pong.GetAsync("api/pong");
            response.EnsureSuccessStatusCode();

            _logger.LogInformation("Pong function has been invoked successfully.");
            return new OkResult();
        }
        catch (Exception exception)
        {
            const string errorMessage = "Failed to invoke Pong function.";
            _logger.LogError(exception, errorMessage);
            return new ObjectResult(errorMessage) { StatusCode = StatusCodes.Status500InternalServerError };
        }
    }
}
