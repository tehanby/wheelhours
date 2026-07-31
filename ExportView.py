from QueryOptimizer import QueryOptimizer

class ExportView:
    def __init__(self, db_url):
        self.optimizer = QueryOptimizer(db_url)

    def display_logs(self):
        page_number = 1
        page_size = 50
        while True:
            logs = self.optimizer.fetch_drive_logs(page_number, page_size)
            if not logs:
                break
            for log in logs:
                print(log.log_entry)
            page_number += 1

# Example usage
if __name__ == "__main__":
    view = ExportView('sqlite:///example.db')
    view.display_logs()
