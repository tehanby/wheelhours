from tkinter import *
from .supervisor import Supervisor

def add_supervisor():
    supervisor_name = name_entry.get()
    supervisor_email = email_entry.get()

    try:
        supervisor = Supervisor.create_supervisor({'name': supervisor_name, 'email': supervisor_email})
        # Logic to store the supervisor data (e.g., save to file or database)
        print(f"Supervisor added: {supervisor.name}, {supervisor.email}")
    except ValueError as e:
        error_label.config(text=str(e))

root = Tk()
root.title("Add Supervisor")

Label(root, text="Name").grid(row=0, column=0)
name_entry = Entry(root)
name_entry.grid(row=0, column=1)

Label(root, text="Email").grid(row=1, column=0)
email_entry = Entry(root)
email_entry.grid(row=1, column=1)

Button(root, text="Add Supervisor", command=add_supervisor).grid(row=2, columnspan=2)

error_label = Label(root, text="", fg="red")
error_label.grid(row=3, columnspan=2)

root.mainloop()
