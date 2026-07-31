using System.Collections.ObjectModel;
using System.Windows.Input;

namespace wheelhours.ViewModels
{
    public class ManualLogViewModel : BaseViewModel
    {
        private ObservableCollection<LogEntry> _logEntries = new ObservableCollection<LogEntry>();
        public ObservableCollection<LogEntry> LogEntries
        {
            get => _logEntries;
            set { _logEntries = value; OnPropertyChanged(); }
        }

        private string _newLogDescription;
        public string NewLogDescription
        {
            get => _newLogDescription;
            set { _newLogDescription = value; OnPropertyChanged(); }
        }

        public ICommand AddLogCommand { get; set; }

        public ManualLogViewModel()
        {
            AddLogCommand = new Command(AddNewLog);
        }

        private void AddNewLog()
        {
            if (!string.IsNullOrWhiteSpace(NewLogDescription))
            {
                var newLogEntry = new LogEntry
                {
                    Description = NewLogDescription,
                    TimeStamp = DateTime.Now
                };

                LogEntries.Add(newLogEntry);
                NewLogDescription = string.Empty;
            }
        }
    }

    public class LogEntry
    {
        public string Description { get; set; }
        public DateTime TimeStamp { get; set; }
    }
}
