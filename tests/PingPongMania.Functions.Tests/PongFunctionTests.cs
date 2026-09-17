using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using PingPongMania.PongFunctions;

namespace PingPongMania.Functions.Tests;

public class PongFunctionTests
{
    [Fact]
    public void Run_ReturnsOk()
    {
        var function = new PongFunction(NullLogger<PongFunction>.Instance);
        var request = new DefaultHttpContext().Request;

        var result = function.Run(request);

        Assert.IsType<OkResult>(result);
    }
}
