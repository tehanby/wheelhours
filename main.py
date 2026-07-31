from .integration import Integration

def main():
    integration = Integration()
    
    # Example usage
    task_id = "12345"
    integration.add_task(task_id, {"description": "Complete project report", "assignee": "John Doe"})
    integration.integrate_supervisor_sign_off(task_id)
    rejected = integration.reject_supervisor_sign_off(task_id)

if __name__ == "__main__":
    main()
