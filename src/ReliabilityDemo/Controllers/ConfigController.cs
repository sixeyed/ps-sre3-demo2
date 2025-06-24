using Microsoft.AspNetCore.Mvc;
using ReliabilityDemo.Models;
using ReliabilityDemo.Services;

namespace ReliabilityDemo.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ConfigController : ControllerBase
{
    private readonly FailureSimulator _failureSimulator;
    private readonly ILogger<ConfigController> _logger;

    public ConfigController(FailureSimulator failureSimulator, ILogger<ConfigController> logger)
    {
        _failureSimulator = failureSimulator;
        _logger = logger;
    }

    [HttpGet]
    public IActionResult GetConfig()
    {
        _logger.LogDebug("Getting current failure configuration");
        return Ok(_failureSimulator.Config);
    }

    [HttpPost]
    public IActionResult UpdateConfig([FromBody] FailureConfig config)
    {
        _logger.LogDebug("Updating failure configuration: {@Config}", config);
        _failureSimulator.Config = config;
        return Ok(new { message = "Configuration updated successfully" });
    }

    [HttpPost("reset")]
    public IActionResult ResetConfig()
    {
        _logger.LogDebug("Resetting failure configuration to defaults");
        _failureSimulator.Config = new FailureConfig();
        return Ok(new { message = "Configuration reset to defaults" });
    }
}