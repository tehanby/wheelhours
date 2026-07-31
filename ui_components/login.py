import tkinter as tk
from tkinter import messagebox

class LoginPage(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Login")
        self.geometry("300x200")

        self.username_var = tk.StringVar()
        self.password_var = tk.StringVar()

        tk.Label(self, text="Username:").pack(pady=5)
        tk.Entry(self, textvariable=self.username_var).pack(pady=5)

        tk.Label(self, text="Password:").pack(pady=5)
        tk.Entry(self, textvariable=self.password_var, show="*").pack(pady=5)

        remember_me = tk.BooleanVar()
        tk.Checkbutton(self, text="Remember me", variable=remember_me).pack(pady=5)

        login_button = tk.Button(self, text="Login", command=self.login)
        login_button.pack(pady=10)

    def login(self):
        username = self.username_var.get()
        password = self.password_var.get()

        if username == "admin" and password == "password":
            messagebox.showinfo("Success", "Logged in successfully!")
            self.destroy()
        else:
            messagebox.showerror("Error", "Invalid credentials")

if __name__ == "__main__":
    app = LoginPage()
    app.mainloop()
