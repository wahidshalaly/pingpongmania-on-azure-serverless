using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace PingPongMania.PongFunctions;

public class PongFunction
{
    private readonly ILogger<PongFunction> _logger;

    public PongFunction(ILogger<PongFunction> logger)
    {
        _logger = logger;
    }

    [Function("Pong")]
    public IActionResult Run([HttpTrigger(AuthorizationLevel.Function, "get", Route = "pong")] HttpRequest req)
    {
        _logger.LogInformation("Pong function has been invoked.");
        return new OkResult();
    }
}
