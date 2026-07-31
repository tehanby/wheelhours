import tkinter as tk
from task_manager import TaskManager

class TaskUI:
    def __init__(self, root):
        self.root = root
        self.task_manager = TaskManager()
        self.init_ui()

    def init_ui(self):
        self.root.title("Task Manager")

        self.task_id_label = tk.Label(self.root, text="Task ID:")
        self.task_id_entry = tk.Entry(self.root)
        self.supervisor_name_label = tk.Label(self.root, text="Supervisor Name:")
        self.supervisor_name_entry = tk.Entry(self.root)

        self.add_task_button = tk.Button(self.root, text="Add Task", command=self.add_task)
        self.sign_off_button = tk.Button(self.root, text="Sign Off Task", command=self.sign_off_task)

        self.task_id_label.grid(row=0, column=0)
        self.task_id_entry.grid(row=0, column=1)
        self.supervisor_name_label.grid(row=1, column=0)
        self.supervisor_name_entry.grid(row=1, column=1)

        self.add_task_button.grid(row=2, column=0)
        self.sign_off_button.grid(row=2, column=1)

    def add_task(self):
        task_id = self.task_id_entry.get()
        task = {'id': task_id, 'signed_off': False}
        self.task_manager.add_task(task)
        self.task_id_entry.delete(0, tk.END)
        self.supervisor_name_entry.delete(0, tk.END)

    def sign_off_task(self):
        task_id = self.task_id_entry.get()
        supervisor_name = self.supervisor_name_entry.get()
        if self.task_manager.sign_off_task(task_id, supervisor_name):
            print(f"Task {task_id} signed off by {supervisor_name}")
        else:
            print("Task not found or already signed off")
