using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using PingPongMania.PlayFunctions;

namespace PingPongMania.Functions.Tests;

public class PlayFunctionTests
{
    [Fact]
    public async Task Get_ReturnsOk_WhenPingSucceeds()
    {
        var pingClient = new Mock<IPingClient>();
        pingClient.Setup(c => c.InvokeAsync()).Returns(Task.CompletedTask);
        var function = new PlayFunction(pingClient.Object, NullLogger<PlayFunction>.Instance);

        var result = await function.Get(new DefaultHttpContext().Request);

        Assert.IsType<OkResult>(result);
    }

    [Fact]
    public async Task Get_Returns500_WhenPingFails()
    {
        var pingClient = new Mock<IPingClient>();
        pingClient.Setup(c => c.InvokeAsync()).ThrowsAsync(new HttpRequestException("boom"));
        var function = new PlayFunction(pingClient.Object, NullLogger<PlayFunction>.Instance);

        var result = await function.Get(new DefaultHttpContext().Request);

        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }
}
