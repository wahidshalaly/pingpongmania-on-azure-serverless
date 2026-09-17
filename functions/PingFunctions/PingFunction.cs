using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace PingPongMania.PingFunctions;

public class PingFunction
{
    private readonly PongClient _pongClient;
    private readonly ILogger<PingFunction> _logger;

    public PingFunction(PongClient pongClient, ILogger<PingFunction> logger)
    {
        _pongClient = pongClient;
        _logger = logger;
    }

    [Function("Ping")]
    public async Task<IActionResult> Reply([HttpTrigger(AuthorizationLevel.Function, "get", Route = "ping")] HttpRequest req)
    {
        _logger.LogInformation("Ping function has been invoked.");

        try
        {
            await _pongClient.InvokeAsync();
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
