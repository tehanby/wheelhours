import unittest
from relative.path.to.supervisor_sign_off import SupervisorSignOff
from relative.path.to.data_store import DataStore

class TestSupervisorSignOff(unittest.TestCase):
    def setUp(self):
        self.data_store = DataStore()
        self.supervisor_sign_off = SupervisorSignOff(self.data_store)

    def test_sign_off_success(self):
        request_id = '12345'
        supervisor_id = 'S123'
        
        # Add a request with status 'pending' to the data store
        request_details = {'status': 'pending'}
        self.data_store.add_request(request_id, request_details)
        
        # Attempt to sign off on the request
        result = self.supervisor_sign_off.sign_off(request_id, supervisor_id)
        
        # Check if signing off was successful and request status is updated
        self.assertTrue(result)
        updated_request = self.data_store.get_request(request_id)
        self.assertEqual(updated_request['status'], 'approved')

    def test_sign_off_failure(self):
        request_id = '12345'
        supervisor_id = 'S999'  # Supervisor not authorized to sign off
        
        # Add a request with status 'pending' to the data store
        request_details = {'status': 'pending'}
        self.data_store.add_request(request_id, request_details)
        
        # Attempt to sign off on the request
        result = self.supervisor_sign_off.sign_off(request_id, supervisor_id)
        
        # Check if signing off was unsuccessful
        self.assertFalse(result)

if __name__ == '__main__':
    unittest.main()
