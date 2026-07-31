from .supervisor import Supervisor
from .task_manager import TaskManager

class Integration:
    def __init__(self):
        self.supervisor = Supervisor()
        self.task_manager = TaskManager()

    def integrate_supervisor_sign_off(self, task_id):
        # Logic to integrate supervisor sign-off with task management system
        if self.task_manager.update_task_status(task_id, "pending_approval"):
            return self.supervisor.sign_off_task(task_id)
        else:
            print(f"Failed to update status for task {task_id} before signing off.")
            return False

    def reject_supervisor_sign_off(self, task_id):
        # Logic to handle rejection of supervisor sign-off
        if self.task_manager.update_task_status(task_id, "rejected"):
            return self.supervisor.reject_task(task_id)
        else:
            print(f"Failed to update status for task {task_id} before rejecting.")
            return False
