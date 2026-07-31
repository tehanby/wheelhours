import requests

class DataService:
    def fetch_data(self, endpoint):
        """
        Fetches data from the given API endpoint.
        
        Args:
            endpoint (str): The URL of the API endpoint.
            
        Returns:
            dict or list: JSON response from the API.
        """
        try:
            response = requests.get(endpoint)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            print(f"Failed to fetch data from {endpoint}: {e}")
            return None
