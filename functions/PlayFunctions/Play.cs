using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace PingPongMania.PlayFunctions;

public class Play(IPingClient pingClient, ILogger<Play> logger)
{
    [Function("Play")]
    public async Task<IActionResult> Get(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "play")] HttpRequest req
    )
    {
        logger.LogInformation("Play function has been invoked.");

        try
        {
            await pingClient.InvokeAsync();
            return new OkResult();
        }
        catch (Exception exception)
        {
            const string errorMessage = "Failed to call Ping function.";
            logger.LogError(exception, errorMessage);
            return new ObjectResult(errorMessage)
            {
                StatusCode = StatusCodes.Status500InternalServerError,
            };
        }
    }
}
