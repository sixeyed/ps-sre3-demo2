using Microsoft.AspNetCore.Mvc;

namespace ReliabilityDemo.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    private readonly ILogger<HealthController> _logger;

    public HealthController(ILogger<HealthController> logger)
    {
        _logger = logger;
    }

    [HttpGet]
    public IActionResult Health()
    {
        _logger.LogDebug("Health check requested");
        return Ok(new { 
            status = "healthy", 
            timestamp = DateTime.UtcNow,
            uptime = Environment.TickCount64
        });
    }
}