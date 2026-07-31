import os
import subprocess

def run_usability_tests():
    # This function is intended to run usability tests and collect feedback.
    print("Running usability tests...")
    
    # Path to the prototype application
    prototype_path = "C:\\AI_Workspace\\wheelhours\\prototype.exe"
    
    if not os.path.exists(prototype_path):
        return "Prototype not found at the specified path."
    
    try:
        # Running the prototype as a subprocess to simulate user testing
        result = subprocess.run([prototype_path], capture_output=True, text=True, check=True)
        print("Test run complete. Output:")
        print(result.stdout)
        
        # Collect feedback (this is a mock implementation)
        feedback = input("Please provide your feedback on the usability of the prototype: ")
        
        return f"Feedback collected: {feedback}"
    except subprocess.CalledProcessError as e:
        return f"Failed to run tests. Error: {e.stderr}"

# Example usage
if __name__ == "__main__":
    test_result = run_usability_tests()
    print(test_result)
