from ui.supervisor_ui import root

def on_first_open():
    if not supervisor_exists():
        root.mainloop()

def supervisor_exists():
    # Logic to check if supervisor data already exists (e.g., file or database)
    return False

if __name__ == "__main__":
    on_first_open()
