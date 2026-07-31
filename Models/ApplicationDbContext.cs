using Microsoft.EntityFrameworkCore;
using WheelHours.Models;

namespace WheelHours.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<DriveLog> DriveLogs { get; set; }
    }
}
