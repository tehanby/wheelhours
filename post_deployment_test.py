import unittest
from wheelhours import app  # Assuming your main app is in this module

class TestPostDeployment(unittest.TestCase):
    def setUp(self):
        app.config['TESTING'] = True
        self.app = app.test_client()
        self.app.testing = True

    def test_homepage_loads(self):
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Welcome to WheelHours', response.data)

    def test_login_page_loads(self):
        response = self.app.get('/login')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Login', response.data)

    def test_register_page_loads(self):
        response = self.app.get('/register')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Register', response.data)

if __name__ == '__main__':
    unittest.main()
