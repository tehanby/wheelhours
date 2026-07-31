import unittest
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

class TestOnboardingFlow(unittest.TestCase):
    def setUp(self):
        self.driver = webdriver.Chrome()
        self.driver.get("http://localhost:8000/onboarding")  # Replace with your actual URL

    def tearDown(self):
        self.driver.quit()

    def test_add_supervisor(self):
        driver = self.driver
        add_supervisor_button = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.ID, "add-supervisor-button"))
        )
        add_supervisor_button.click()

        # Assuming there's an input field for the supervisor name
        supervisor_name_input = driver.find_element(By.ID, "supervisor-name")
        supervisor_name_input.send_keys("Test Supervisor")

        # Assuming there's a submit button to save the supervisor
        submit_supervisor_button = driver.find_element(By.ID, "submit-supervisor-button")
        submit_supervisor_button.click()

        # Check if the supervisor was added successfully
        success_message = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.ID, "success-message"))
        )
        self.assertIn("Supervisor added successfully", success_message.text)

    def test_add_vehicle(self):
        driver = self.driver
        add_vehicle_button = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.ID, "add-vehicle-button"))
        )
        add_vehicle_button.click()

        # Assuming there's an input field for the vehicle name
        vehicle_name_input = driver.find_element(By.ID, "vehicle-name")
        vehicle_name_input.send_keys("Test Vehicle")

        # Assuming there's a submit button to save the vehicle
        submit_vehicle_button = driver.find_element(By.ID, "submit-vehicle-button")
        submit_vehicle_button.click()

        # Check if the vehicle was added successfully
        success_message = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.ID, "success-message"))
        )
        self.assertIn("Vehicle added successfully", success_message.text)

    def test_smooth_transitions(self):
        driver = self.driver

        # Test adding a supervisor and then a vehicle
        add_supervisor_button = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.ID, "add-supervisor-button"))
        )
        add_supervisor_button.click()

        supervisor_name_input = driver.find_element(By.ID, "supervisor-name")
        supervisor_name_input.send_keys("Test Supervisor")

        submit_supervisor_button = driver.find_element(By.ID, "submit-supervisor-button")
        submit_supervisor_button.click()

        add_vehicle_button = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.ID, "add-vehicle-button"))
        )
        add_vehicle_button.click()

        vehicle_name_input = driver.find_element(By.ID, "vehicle-name")
        vehicle_name_input.send_keys("Test Vehicle")

        submit_vehicle_button = driver.find_element(By.ID, "submit-vehicle-button")
        submit_vehicle_button.click()

        # Check if both supervisor and vehicle were added successfully
        success_message = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.ID, "success-message"))
        )
        self.assertIn("Supervisor and Vehicle added successfully", success_message.text)

if __name__ == "__main__":
    unittest.main()
