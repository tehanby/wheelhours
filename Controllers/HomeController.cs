using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;

namespace WheelHours.Controllers
{
    public class HomeController : Controller
    {
        private readonly ApplicationDbContext _context;

        public HomeController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public IActionResult Index()
        {
            return View();
        }
    }
}
