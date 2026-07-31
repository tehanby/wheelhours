from flask import Flask, jsonify, request
import random

app = Flask(__name__)

@app.route('/api/telematics', methods=['GET'])
def get_telematics_data():
    # Simulate real-time telematics data
    timestamp = datetime.datetime.now().isoformat()
    speed = round(random.uniform(20, 100), 2)  # Random speed between 20 and 100 mph
    return jsonify({'timestamp': timestamp, 'speed': speed})

if __name__ == '__main__':
    app.run(debug=True)
