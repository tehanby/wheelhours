class ComplianceEngine:
    def __init__(self):
        self.rules = {}

    def add_rule(self, rule_name, rule_function):
        """Add a new rule to the engine."""
        if rule_name in self.rules:
            raise ValueError(f"Rule '{rule_name}' already exists.")
        self.rules[rule_name] = rule_function

    def remove_rule(self, rule_name):
        """Remove an existing rule from the engine."""
        if rule_name not in self.rules:
            raise ValueError(f"Rule '{rule_name}' does not exist.")
        del self.rules[rule_name]

    def check_compliance(self, operation):
        """Check if a single operation complies with all rules."""
        for rule_function in self.rules.values():
            if not rule_function(operation):
                return False
        return True

    def check_operations(self, operations):
        """Check multiple operations at once."""
        results = []
        for operation in operations:
            results.append(self.check_compliance(operation))
        return results
