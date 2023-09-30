from flask import Flask, request, jsonify
import os
import boto3
from botocore.exceptions import NoCredentialsError
from flask_cors import CORS

app = Flask(__name__)

# Initialize a DynamoDB client
dynamodb = boto3.client(
    'dynamodb',
    region_name=os.environ.get('AWS_REGION'),
    aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY'),
    aws_session_token=os.environ.get('AWS_SESSION_TOKEN')  # Only if you're using temporary credentials
)

app = Flask(__name__)
api = CORS(app)

# Check if DynamoDB configuration details are available in environment variables
if not all([os.environ.get('AWS_ACCESS_KEY_ID'), os.environ.get('AWS_SECRET_ACCESS_KEY'), os.environ.get('AWS_REGION')]):
    raise Exception("DynamoDB configuration details not found in environment variables")

# Define the DynamoDB table name
dynamodb_table = os.environ.get('DYNAMODB_TABLE_NAME')

# 1. Add user to DynamoDB
@app.route('/api/v1/users', methods=['POST'])
def add_user():
    if request.method == 'POST':
        if not request.json or not 'username' in request.json or not 'password' in request.json:
            return jsonify({"message": "username or password missing"}), 400

        username = request.json['username']
        password = request.json['password']

        try:
            # Check if the user already exists in DynamoDB
            response = dynamodb.get_item(
                TableName=dynamodb_table,
                Key={'username': {'S': username}}
            )
            if 'Item' in response:
                return jsonify({"message": "user {} already exists".format(username)}), 400
        except Exception as e:
            return jsonify({"message": "Failed to check user existence: {}".format(str(e))}), 500

        try:
            # Add user to DynamoDB
            dynamodb.put_item(
                TableName=dynamodb_table,
                Item={
                    'username': {'S': username},
                    'password': {'S': password}
                }
            )
            return jsonify({"message": "User {} added".format(username)}), 201
        except Exception as e:
            return jsonify({"message": "Failed to add user: {}".format(str(e))}), 500
    else:
        return jsonify({"message": "Method not allowed"}), 405

# 2. Remove user from DynamoDB
@app.route('/api/v1/users/<username>', methods=['DELETE'])
def remove_user(username):
    if request.method == 'DELETE':
        try:
            # Check if the user exists in DynamoDB
            response = dynamodb.get_item(
                TableName=dynamodb_table,
                Key={'username': {'S': username}}
            )
            if 'Item' not in response:
                return jsonify({"message": "User not found"}), 404
        except Exception as e:
            return jsonify({"message": "Failed to check user existence: {}".format(str(e))}), 500

        try:
            # Remove user from DynamoDB
            dynamodb.delete_item(
                TableName=dynamodb_table,
                Key={'username': {'S': username}}
            )
            return jsonify({"message": "User {} removed".format(username)}), 200
        except Exception as e:
            return jsonify({"message": "Failed to remove user: {}".format(str(e))}), 500
    else:
        return jsonify({"message": "Method not allowed"}), 405

# 3. List all users from DynamoDB
@app.route('/api/v1/users', methods=['GET'])
def list_all_users():
    if request.method == 'GET':
        try:
            # Scan the DynamoDB table to list all users
            response = dynamodb.scan(
                TableName=dynamodb_table,
                ProjectionExpression='username'
            )
            users = [item['username']['S'] for item in response.get('Items', [])]
            return jsonify(users), 200
        except Exception as e:
            return jsonify({"message": "Failed to list users: {}".format(str(e))}), 500
    else:
        return jsonify({"message": "Method not allowed"}), 405

@app.route('/')
def home():
    return "User account management app is working! Owner: CloudComp2"

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=80)
