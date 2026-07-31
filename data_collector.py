import datetime
import logging

# Initialize logging configuration
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class TelematicsDataCollector:
    def __init__(self):
        self.data_store = []

    def collect_data(self, vehicle_id, data):
        """
        Collects telematics data from a connected vehicle.
        
        Args:
            vehicle_id (str): The unique identifier for the vehicle.
            data (dict): The data collected from the vehicle.
        
        Returns:
            None
        """
        timestamp = datetime.datetime.now()
        entry = {
            'vehicle_id': vehicle_id,
            'timestamp': timestamp,
            'data': data
        }
        self.data_store.append(entry)
        logging.info(f"Data collected for vehicle {vehicle_id} at {timestamp}")

    def process_data(self):
        """
        Processes the collected telematics data.
        
        Returns:
            list: A list of processed data entries.
        """
        processed_data = []
        for entry in self.data_store:
            # Example processing: add a flag indicating if the speed is above 60 km/h
            if 'speed' in entry['data'] and entry['data']['speed'] > 60:
                entry['data']['is_speeding'] = True
            else:
                entry['data']['is_speeding'] = False
            processed_data.append(entry)
        return processed_data

    def save_data(self, file_path):
        """
        Saves the processed data to a file.
        
        Args:
            file_path (str): The path where the data should be saved.
        
        Returns:
            None
        """
        with open(file_path, 'w') as file:
            for entry in self.processed_data():
                file.write(f"{entry}\n")
        logging.info(f"Data saved to {file_path}")

    def read_data(self, file_path):
        """
        Reads data from a file and stores it in the collector.
        
        Args:
            file_path (str): The path where the data is stored.
        
        Returns:
            None
        """
        with open(file_path, 'r') as file:
            for line in file:
                self.data_store.append(eval(line.strip()))
        logging.info(f"Data read from {file_path}")
