namespace ReliabilityDemo.DataStore.Models;

public class DistributedCacheConfig
{
    public bool Enabled { get; set; } = false;
    public int ExpirationSeconds { get; set; } = 300;
}