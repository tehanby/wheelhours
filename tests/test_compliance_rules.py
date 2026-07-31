import unittest
from ..compliance_rules import GDLComplianceRules

class TestGDLComplianceRules(unittest.TestCase):
    def test_is_compliant(self):
        rules = GDLComplianceRules("GDPR")
        transaction1 = {"amount": 100, "currency": "USD", "country": "US"}
        self.assertFalse(rules.is_compliant(transaction1))

if __name__ == "__main__":
    unittest.main()
