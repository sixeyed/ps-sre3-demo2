namespace ReliabilityDemo.Models;

public class DistributedCacheConfig
{
    public bool Enabled { get; set; } = false;
    public int ExpirationSeconds { get; set; } = 300; // 5 minutes default
}