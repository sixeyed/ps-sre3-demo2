using Microsoft.EntityFrameworkCore;
using ReliabilityDemo.DataStore.Models;

namespace ReliabilityDemo.DataStore.Data;

public class ReliabilityDemoContext : DbContext
{
    public ReliabilityDemoContext(DbContextOptions<ReliabilityDemoContext> options) : base(options)
    {
    }
    
    public DbSet<Customer> Customers { get; set; }
    
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        
        modelBuilder.Entity<Customer>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Email).IsUnique();
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
        });
    }
}