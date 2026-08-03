import os
from datetime import datetime

class App:
    def __init__(self):
        self.onboarded = self.check_onboarding_status()

    def check_onboarding_status(self):
        onboard_file_path = 'C:\\AI_Workspace\\wheelhours\\.onboarded'
        if not os.path.exists(onboard_file_path):
            return False
        with open(onboard_file_path, 'r') as file:
            last_access_time = datetime.fromisoformat(file.read().strip())
            current_time = datetime.now()
            time_difference = (current_time - last_access_time).days
            return time_difference < 7

    def run(self):
        if not self.onboarded:
            self.show_onboarding()
        else:
            self.main_menu()

    def show_onboarding(self):
        print("Welcome to WheelHours!")
        print("Before we get started, let's set up your account.")
        self.add_supervisor()
        self.add_vehicle()
        with open('C:\\AI_Workspace\\wheelhours\\.onboarded', 'w') as file:
            file.write(datetime.now().isoformat())

    def add_supervisor(self):
        supervisor_name = input("Please enter the name of your supervisor: ")
        print(f"Supervisor {supervisor_name} added successfully.")

    def add_vehicle(self):
        vehicle_model = input("Please enter the model of your vehicle: ")
        print(f"Vehicle {vehicle_model} added successfully.")

    def main_menu(self):
        while True:
            print("\nMain Menu")
            print("1. View Work Hours")
            print("2. Edit Vehicle")
            print("3. Exit")
            choice = input("Select an option: ")
            if choice == '1':
                self.view_work_hours()
            elif choice == '2':
                self.edit_vehicle()
            elif choice == '3':
                break
            else:
                print("Invalid option. Please try again.")

    def view_work_hours(self):
        print("Work hours will be displayed here.")

    def edit_vehicle(self):
        vehicle_model = input("Enter the model of the vehicle you want to edit: ")
        # Add logic to edit the vehicle details

if __name__ == "__main__":
    app = App()
    app.run()
