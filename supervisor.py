class Supervisor:
    def sign_off_task(self, task_id):
        # Logic to handle supervisor sign-off for a specific task
        print(f"Task {task_id} signed off by supervisor.")
        return True

    def reject_task(self, task_id):
        # Logic to handle rejection of a specific task
        print(f"Task {task_id} rejected by supervisor.")
        return False
