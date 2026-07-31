from .Onboarding import Onboarding
from .VehicleManager import VehicleManager
from .SupervisorManager import SupervisorManager

class App:
    def __init__(self):
        self.onboarding = Onboarding()
        self.vehicle_manager = VehicleManager()
        self.supervisor_manager = SupervisorManager()

    def launch(self):
        if not self.is_first_launch():
            self.show_onboarding()
        
        # Assuming the app starts by asking for vehicle addition
        self.vehicle_manager.add_vehicle()
    
    def is_first_launch(self):
        # This should be replaced with actual logic to check if it's the first launch
        return False
    
    def show_onboarding(self):
        self.onboarding.display()

class Onboarding:
    def display(self):
        print("Welcome to WheelHours!")
        print("1. Add a Supervisor")
        print("2. Add a Vehicle")

# Additional classes like VehicleManager and SupervisorManager can be created similarly
