using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace PingPongMania.PingFunctions;

public class Ping(IPongClient pongClient, ILogger<Ping> logger)
{
    [Function("Ping")]
    public async Task<IActionResult> Reply(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "ping")] HttpRequest req
    )
    {
        logger.LogInformation("Ping function has been invoked.");

        try
        {
            await pongClient.InvokeAsync();
            return new OkResult();
        }
        catch (Exception exception)
        {
            const string errorMessage = "Failed to invoke Pong function.";
            logger.LogError(exception, errorMessage);
            return new ObjectResult(errorMessage)
            {
                StatusCode = StatusCodes.Status500InternalServerError,
            };
        }
    }
}
