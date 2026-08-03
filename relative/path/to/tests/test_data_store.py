import unittest
from relative.path.to.data_store import DataStore

class TestDataStore(unittest.TestCase):
    def setUp(self):
        self.data_store = DataStore()

    def test_add_request_success(self):
        request_id = '12345'
        request_details = {'status': 'pending'}
        
        # Add a request to the data store
        self.data_store.add_request(request_id, request_details)
        
        # Retrieve and check if the request was added successfully
        retrieved_request = self.data_store.get_request(request_id)
        self.assertIsNotNone(retrieved_request)
        self.assertEqual(retrieved_request['status'], 'pending')

    def test_update_request_success(self):
        request_id = '12345'
        initial_details = {'status': 'pending'}
        updated_details = {'status': 'approved'}
        
        # Add a request and then update it
        self.data_store.add_request(request_id, initial_details)
        self.data_store.update_request(request_id, updated_details)
        
        # Retrieve and check if the request was updated successfully
        retrieved_request = self.data_store.get_request(request_id)
        self.assertIsNotNone(retrieved_request)
        self.assertEqual(retrieved_request['status'], 'approved')

if __name__ == '__main__':
    unittest.main()
