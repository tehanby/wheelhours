import tkinter as tk

class Dashboard(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Dashboard")
        self.geometry("800x600")

        overview_frame = tk.Frame(self)
        overview_frame.pack(pady=20)

        tk.Label(overview_frame, text="Welcome, User!", font=("Arial", 16)).pack(pady=10)
        tk.Label(overview_frame, text="Current Hours: 40").pack(pady=5)
        tk.Label(overview_frame, text="Remaining Hours: 60").pack(pady=5)

        project_list = tk.Frame(self)
        project_list.pack(pady=20)

        for i in range(3):
            tk.Label(project_list, text=f"Project {i+1}: In Progress", font=("Arial", 14)).pack(anchor=tk.W, pady=5)

if __name__ == "__main__":
    app = Dashboard()
    app.mainloop()
