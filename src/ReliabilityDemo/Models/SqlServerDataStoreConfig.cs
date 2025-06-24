namespace ReliabilityDemo.Models;

public class SqlServerDataStoreConfig
{
    public int MaxConcurrentClients { get; set; } = 5;
    public bool AutoMigrate { get; set; } = true;
}