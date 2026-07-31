import os
from flask import Flask, request, jsonify

app = Flask(__name__)

# Define a dictionary to store vehicle data temporarily
vehicle_data_store = {}

@app.route('/add_vehicle', methods=['POST'])
def add_vehicle():
    # Retrieve the vehicle data from the request
    vehicle_info = request.json
    
    # Validate the vehicle data (example validation)
    if 'make' not in vehicle_info or 'model' not in vehicle_info:
        return jsonify({"error": "Make and model are required"}), 400
    
    # Store the vehicle data in the dictionary (simulating storage)
    vehicle_id = len(vehicle_data_store) + 1
    vehicle_data_store[vehicle_id] = vehicle_info
    
    # Return a success response with the stored vehicle data
    return jsonify({"message": "Vehicle added successfully", "vehicle_id": vehicle_id, "vehicle": vehicle_info}), 200

if __name__ == '__main__':
    app.run(debug=True)
