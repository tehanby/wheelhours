using System;
using System.ComponentModel.DataAnnotations;

namespace WheelHours
{
    public class ManualLogViewModel
    {
        [Required(ErrorMessage = "Start time is required.")]
        [DataType(DataType.DateTime)]
        public DateTime StartTime { get; set; }

        [Required(ErrorMessage = "End time is required.")]
        [DataType(DataType.DateTime)]
        public DateTime EndTime { get; set; }

        public bool IsValid()
        {
            if (StartTime >= EndTime)
            {
                ErrorMessage = "End time cannot be before start time.";
                return false;
            }
            return true;
        }

        public string ErrorMessage { get; private set; }
    }
}
