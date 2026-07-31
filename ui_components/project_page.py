import tkinter as tk

class ProjectPage(tk.Tk):
    def __init__(self, project_name):
        super().__init__()
        self.title(f"Project: {project_name}")
        self.geometry("600x400")

        project_info = tk.Frame(self)
        project_info.pack(pady=20)

        tk.Label(project_info, text=f"Project Name: {project_name}", font=("Arial", 18)).pack(pady=10)
        tk.Label(project_info, text="Total Hours Worked: 50").pack(pady=5)

        task_list = tk.Frame(self)
        task_list.pack(pady=20)

        for i in range(3):
            tk.Label(task_list, text=f"Task {i+1}: 8 hours logged", font=("Arial", 14)).pack(anchor=tk.W, pady=5)

        add_task_button = tk.Button(self, text="Add New Task")
        add_task_button.pack(pady=20)

if __name__ == "__main__":
    app = ProjectPage("Project Alpha")
    app.mainloop()
