from flask import Flask, request, jsonify
from .services import fetch_user_progress, update_user_progress

app = Flask(__name__)

@app.route('/user/progress', methods=['GET'])
def get_user_progress():
    user_id = request.args.get('user_id')
    if user_id:
        progress = fetch_user_progress(int(user_id))
        if progress:
            return jsonify(progress), 200
        else:
            return jsonify({'error': 'User not found'}), 404
    else:
        return jsonify({'error': 'User ID is required'}), 400

@app.route('/user/progress', methods=['POST'])
def update_progress():
    data = request.json
    user_id = data.get('user_id')
    course_id = data.get('course_id')
    if user_id and course_id:
        updated = update_user_progress(int(user_id), int(course_id))
        if updated:
            return jsonify({'message': 'Progress updated successfully'}), 200
        else:
            return jsonify({'error': 'Course not found or already completed'}), 400
    else:
        return jsonify({'error': 'User ID and Course ID are required'}), 400

if __name__ == '__main__':
    app.run(debug=True)
