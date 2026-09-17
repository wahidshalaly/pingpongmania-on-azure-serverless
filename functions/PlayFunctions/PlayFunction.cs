using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace PingPongMania.PlayFunctions;

public class PlayFunction
{
    private readonly IPingClient _pingClient;
    private readonly ILogger<PlayFunction> _logger;

    public PlayFunction(IPingClient pingClient, ILogger<PlayFunction> logger)
    {
        _pingClient = pingClient;
        _logger = logger;
    }

    [Function("Play")]
    public async Task<IActionResult> Get([HttpTrigger(AuthorizationLevel.Function, "get", Route = "play")] HttpRequest req)
    {
        _logger.LogInformation("Play function has been invoked.");

        try
        {
            await _pingClient.InvokeAsync();
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
