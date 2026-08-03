class DataStore:
    def __init__(self):
        self.data = {}

    def add_request(self, request_id, details):
        """
        Adds a new request to the data store.
        
        :param request_id: ID of the request
        :param details: Dictionary containing details of the request
        """
        # Implement logic to add a request to the data store
        pass

    def get_request(self, request_id):
        """
        Retrieves a request from the data store.
        
        :param request_id: ID of the request to retrieve
        :return: Dictionary containing details of the request if found, None otherwise
        """
        # Implement logic to fetch a request from the data store
        pass

    def update_request(self, request_id, updates):
        """
        Updates an existing request in the data store.
        
        :param request_id: ID of the request to be updated
        :param updates: Dictionary containing updates for the request
        """
        # Implement logic to update a request in the data store
        pass
