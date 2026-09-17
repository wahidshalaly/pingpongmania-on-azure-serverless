using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using PingPongMania.PingFunctions;

namespace PingPongMania.Functions.Tests;

public class PingFunctionTests
{
    [Fact]
    public async Task Reply_ReturnsOk_WhenPongSucceeds()
    {
        var pongClient = new Mock<IPongClient>();
        pongClient.Setup(c => c.InvokeAsync()).Returns(Task.CompletedTask);
        var function = new PingFunction(pongClient.Object, NullLogger<PingFunction>.Instance);

        var result = await function.Reply(new DefaultHttpContext().Request);

        Assert.IsType<OkResult>(result);
    }

    [Fact]
    public async Task Reply_Returns500_WhenPongFails()
    {
        var pongClient = new Mock<IPongClient>();
        pongClient.Setup(c => c.InvokeAsync()).ThrowsAsync(new HttpRequestException("boom"));
        var function = new PingFunction(pongClient.Object, NullLogger<PingFunction>.Instance);

        var result = await function.Reply(new DefaultHttpContext().Request);

        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }
}
