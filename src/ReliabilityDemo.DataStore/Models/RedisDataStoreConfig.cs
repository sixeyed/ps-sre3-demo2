namespace ReliabilityDemo.DataStore.Models;

public class RedisDataStoreConfig
{
    public int MaxConcurrentClients { get; set; } = 5;
}