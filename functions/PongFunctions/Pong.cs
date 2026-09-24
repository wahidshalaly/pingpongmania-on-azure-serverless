using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace PingPongMania.PongFunctions;

public class Pong(ILogger<Pong> logger)
{
    [Function("Pong")]
    public IActionResult Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "pong")] HttpRequest req
    )
    {
        logger.LogInformation("Pong function has been invoked.");
        return new OkResult();
    }
}
