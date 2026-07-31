class TaskManager:
    def __init__(self):
        self.tasks = {}

    def add_task(self, task_id, details):
        # Logic to add a new task
        self.tasks[task_id] = details
        print(f"Task {task_id} added with details: {details}")

    def update_task_status(self, task_id, status):
        # Logic to update the status of a task
        if task_id in self.tasks:
            self.tasks[task_id]['status'] = status
            print(f"Task {task_id} updated to status: {status}")
            return True
        return False

    def get_task_details(self, task_id):
        # Logic to retrieve details of a specific task
        if task_id in self.tasks:
            return self.tasks[task_id]
        return None
