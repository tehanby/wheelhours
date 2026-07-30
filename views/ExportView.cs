using System;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using System.Linq;

namespace WheelHours.Controllers
{
    public class ExportViewController : Controller
    {
        private readonly ApplicationDbContext _context;

        public ExportViewController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> FetchDriveLogs(int pageNumber = 1, int pageSize = 50)
        {
            var driveLogsQuery = _context.DriveLogs.AsQueryable();

            // Apply any necessary filters or sorting here
            driveLogsQuery = driveLogsQuery.OrderBy(dl => dl.LogDate);

            // Paginate the results
            var pagedResults = await PaginatedList<DriveLog>.CreateAsync(driveLogsQuery, pageNumber, pageSize);

            return Json(pagedResults);
        }
    }
}
