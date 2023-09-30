from flask import Flask, request, jsonify
import sqlite3
from flask_cors import CORS
import os
import boto3

app = Flask(__name__)


def is_sha1(maybe_sha):
    if len(maybe_sha) != 40:
        return False
    try:
        sha_int = int(maybe_sha, 16)
    except ValueError:
        return False
    return True


app = Flask(__name__)
api = CORS(app)

# 1 Add user--------------------------------------------------------------------


@app.route('/api/v1/users', methods=['POST'])
def add_user():
    if (request.method == 'POST'):
        with sqlite3.connect("users.db") as connectionState:
            cursor = connectionState.cursor()

            if not request.json or not 'username' in request.json or not 'password' in request.json:
                return jsonify({"message": "username or password missing"}), 400

            username = request.json['username']
            password = request.json['password']

            users = cursor.execute("select Username from User")
            users = list(users)
            users = [users[i][0] for i in range(0, len(users))]

            if username in users:
                return jsonify({"message": "user {} already exists".format(username)}), 400

            if not is_sha1(request.json['password']):
                return jsonify({"message": "password not in sha1 format. Enter a proper format"}), 400

            cursor.execute("insert into User values (?, ?)",
                           (username, password))
            return jsonify({"message": "User {} added".format(request.json['username'])}), 201
    else:
        return jsonify({"message": "Method not allowed"}), 405

# 2 Remove user-----------------------------------------------------------------


@app.route('/api/v1/users/<username>', methods=['DELETE'])
def remove_user(username):
    if (request.method == 'DELETE'):
        with sqlite3.connect("users.db") as connectionState:
            cursor = connectionState.cursor()
            users = cursor.execute("select Username from User")
            users = list(users)
            print(username)
            print(users)
            users = [users[i][0] for i in range(0, len(users))]
            if username in users:
                cursor.execute(
                    "delete from User where Username=(?)", (username,))
                return jsonify({"message": "user {} removed".format(username)}), 200
            else:
                return jsonify({"message": "User doesn't exist"}), 400
    else:
        return jsonify({"message": "Method not allowed"}), 405

# 3 List all users--------------------------------------------------------------


@app.route('/api/v1/users', methods=['GET'])
def list_all_users():
    if (request.method == 'GET'):
        with sqlite3.connect("users.db") as connectionState:
            cursor = connectionState.cursor()
            users = cursor.execute("select Username from User")
            users = list(users)
            print(users)
            try:
                dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
                table_name = 'FlaskAppTable'
                # Get a reference to the DynamoDB table
                table = dynamodb.Table(table_name)
                users.append("Table referenced")
            except Exception as e:
                users.append("NTable not referenced")
            users = [users[i][0] for i in range(0, len(users))]
            if (users == []):
                return jsonify({"message": "No users"}), 204
            else:
                return jsonify(users), 200
    else:
        return jsonify({"message": "Method not allowed"}), 405

@app.route('/api/v1/users/dynamo', methods=['GET'])
def list_users():
    if request.method == 'GET':
        dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
        table_name = 'FlaskAppTable'

        # Get a reference to the DynamoDB table
        table = dynamodb.Table(table_name)
        
        table.put_item(Item={'username': "A"})
        table.put_item(Item={'username': "B"})
        table.put_item(Item={'username': "C"})
        table.put_item(Item={'username': "D"})
        table.put_item(Item={'username': "E"})

        response = table.scan(Limit=5)

        users = response.get('Items', [])

        usernames = [user.get('username') for user in users]
        return jsonify(usernames), 200
    else:
        return jsonify({"message": "Method not allowed"}), 405

@app.route('/')
def home():
    return '''<p> User account management app is working! Owner: CloudComp2 </p>
    <p> Please check the <a target="_blank" href="https://github.com/KeshavUpadhyaya/cloud-comp/blob/main/README.md">README</a> for API documentation. </p>
    '''


if __name__ == '__main__':
    # app.run(debug=True,port=8000)
    app.run(host="0.0.0.0", port=80)