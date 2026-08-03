from compliance import ComplianceEngine

def main():
    engine = ComplianceEngine()
    
    # Example rule: Ensure data_access operations are performed by authorized users
    engine.add_rule("authorized_user", lambda operation: operation["user"] in ["john_doe", "jane_doe"])
    
    # Check a single operation
    operation = {
        "id": 1,
        "type": "data_access",
        "user": "john_doe"
    }
    result = engine.check_compliance(operation)
    print(f"Compliance for operation {operation['id']}: {result}")
    
    # Check multiple operations
    operations = [
        {
            "id": 2,
            "type": "data_modification",
            "user": "jane_doe"
        },
        {
            "id": 3,
            "type": "data_access",
            "user": "alice_smith"
        }
    ]
    results = engine.check_operations(operations)
    for i, result in enumerate(results):
        print(f"Compliance for operation {operations[i]['id']}: {result}")

if __name__ == "__main__":
    main()
