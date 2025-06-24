using Microsoft.Extensions.Options;
using ReliabilityDemo.Models;

namespace ReliabilityDemo.Services;

public class FailureSimulator
{
    private readonly Random _random = new();
    private readonly ILogger<FailureSimulator> _logger;
    
    public FailureConfig Config { get; set; }

    public FailureSimulator(ILogger<FailureSimulator> logger, IOptions<FailureConfig> configOptions)
    {
        _logger = logger;
        // Clone the initial config to a mutable object
        var initialConfig = configOptions.Value;
        Config = new FailureConfig
        {
            ConnectionFailureRate = initialConfig.ConnectionFailureRate,
            ReadTimeoutRate = initialConfig.ReadTimeoutRate,
            WriteTimeoutRate = initialConfig.WriteTimeoutRate,
            SlowResponseRate = initialConfig.SlowResponseRate,
            ReadTimeoutMs = initialConfig.ReadTimeoutMs,
            WriteTimeoutMs = initialConfig.WriteTimeoutMs,
            SlowResponseDelayMs = initialConfig.SlowResponseDelayMs
        };
    }

    public async Task SimulateFailures(string operation)
    {
        _logger.LogDebug("Starting failure simulation for operation: {Operation}", operation);

        // Simulate connection failures
        if (ShouldFail(Config.ConnectionFailureRate))
        {
            _logger.LogDebug("Simulating connection failure for operation: {Operation}", operation);
            throw new InvalidOperationException("Connection failed - service unavailable");
        }

        // Simulate read timeouts
        if (operation == "read" && ShouldFail(Config.ReadTimeoutRate))
        {
            _logger.LogDebug("Simulating read timeout for operation: {Operation}, delay: {DelayMs}ms", operation, Config.ReadTimeoutMs);
            await Task.Delay(Config.ReadTimeoutMs);
            throw new TimeoutException("Read operation timed out");
        }

        // Simulate write timeouts
        if (operation == "write" && ShouldFail(Config.WriteTimeoutRate))
        {
            _logger.LogDebug("Simulating write timeout for operation: {Operation}, delay: {DelayMs}ms", operation, Config.WriteTimeoutMs);
            await Task.Delay(Config.WriteTimeoutMs);
            throw new TimeoutException("Write operation timed out");
        }

        // Simulate slow responses
        if (ShouldFail(Config.SlowResponseRate))
        {
            _logger.LogDebug("Simulating slow response for operation: {Operation}, delay: {DelayMs}ms", operation, Config.SlowResponseDelayMs);
            await Task.Delay(Config.SlowResponseDelayMs);
        }

        _logger.LogDebug("Completed failure simulation for operation: {Operation} without failures", operation);
    }

    private bool ShouldFail(double rate)
    {
        var randomValue = _random.NextDouble();
        var shouldFail = randomValue < rate;
        _logger.LogTrace("ShouldFail check: rate={Rate}, random={Random}, result={Result}", rate, randomValue, shouldFail);
        return shouldFail;
    }
}