class TaskManager:
    def __init__(self):
        self.tasks = []

    def add_task(self, task):
        self.tasks.append(task)

    def remove_task(self, task_id):
        for i, task in enumerate(self.tasks):
            if task['id'] == task_id:
                del self.tasks[i]
                break

    def sign_off_task(self, task_id, supervisor_name):
        for task in self.tasks:
            if task['id'] == task_id and not task.get('signed_off'):
                task['signed_off_by'] = supervisor_name
                task['signed_off'] = True
                return True
        return False

    def get_tasks(self):
        return self.tasks
