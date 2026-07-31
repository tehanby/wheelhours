import tkinter as tk

class TaskDetails(tk.Tk):
    def __init__(self, task_title):
        super().__init__()
        self.title(f"Task: {task_title}")
        self.geometry("600x400")

        task_info = tk.Frame(self)
        task_info.pack(pady=20)

        tk.Label(task_info, text=f"Task Title: {task_title}", font=("Arial", 18)).pack(pady=10)
        tk.Label(task_info, text="Description: This is a sample task.", font=("Arial", 14)).pack(pady=5)
        tk.Label(task_info, text="Estimated Hours: 10").pack(pady=5)

        hours_logged = tk.StringVar()
        tk.Label(task_info, text="Hours Logged: ").pack(pady=5)
        tk.Entry(task_info, textvariable=hours_logged).pack(pady=5)

        submit_button = tk.Button(self, text="Submit Hours")
        submit_button.pack(pady=20)

        cancel_button = tk.Button(self, text="Cancel")
        cancel_button.pack(pady=10)

if __name__ == "__main__":
    app = TaskDetails("Task Alpha")
    app.mainloop()
