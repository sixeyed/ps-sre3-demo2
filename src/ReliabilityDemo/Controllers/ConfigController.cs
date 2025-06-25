using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using ReliabilityDemo.Models;

namespace ReliabilityDemo.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ConfigController : ControllerBase
{
    private readonly IOptionsSnapshot<FailureConfig> _failureConfig;
    private readonly ILogger<ConfigController> _logger;

    public ConfigController(IOptionsSnapshot<FailureConfig> failureConfig, ILogger<ConfigController> logger)
    {
        _failureConfig = failureConfig;
        _logger = logger;
    }

    [HttpGet]
    public IActionResult GetConfig()
    {
        _logger.LogDebug("Getting current failure configuration");
        return Ok(_failureConfig.Value);
    }

    [HttpPost]
    public IActionResult UpdateConfig([FromBody] FailureConfig config)
    {
        _logger.LogDebug("Updating failure configuration: {@Config}", config);
        return BadRequest(new { message = "Configuration updates not supported - modify appsettings.json or Helm values" });
    }

    [HttpPost("reset")]
    public IActionResult ResetConfig()
    {
        _logger.LogDebug("Resetting failure configuration to defaults");
        return BadRequest(new { message = "Configuration reset not supported - modify appsettings.json or Helm values" });
    }
}