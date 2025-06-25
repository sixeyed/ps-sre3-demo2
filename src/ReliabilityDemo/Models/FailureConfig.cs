namespace ReliabilityDemo.Models;

public class FailureConfig
{
    public bool Enabled { get; set; }
    public double ConnectionFailureRate { get; set; }
    public double ReadTimeoutRate { get; set; }
    public double WriteTimeoutRate { get; set; }
    public double SlowResponseRate { get; set; }
    public int ReadTimeoutMs { get; set; }
    public int WriteTimeoutMs { get; set; }
    public int SlowResponseDelayMs { get; set; }
}