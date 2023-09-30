# cloud-comp
A simple flask app that can be deployed to AWS using Terraform and Docker. SQLite3 embedded database is used to store data.

Make sure you've installed terraform and you've copied the AWS CLI credentials to '~/.aws/credentials' before running

## Some Notes

- Auto scaling when requests are more than 10 in a minute, runs for 3 times(can go from min 2 to max 5 instances) if requests remain high 
- Down scaling when requests are less than 10 in a minute, runs for 3 times(can go from max 5 to min 2 instances) if requests remain low 
- Access credentials used locally had administration access for the user(but potentially apart from ec2, load balancer, auto scaling groups and stuff, dynamodb access should suffice)
- Issue with no sql database was that each instance have its own copy and therefore their own data and we see different results on each get request
- Extra feature: Did not implement all DynamoDB Apis but a dummy API(/api/v1/users/dynamo) is implemented to show connectivity to dynamoDb works by adding sample values and sending them back
- IAM group configured to allow direct access to dynamoDb without having to manually set any credentials minimizing security risks(like not uploading access_token in repo)



Steps to run:
- `terraform init`
- `terraform apply`
- `terraform destroy` (to destroy the resources provisioned)

## About the app:
The app allows you to manage user accounts.

### 1. Add User

- **Endpoint:** `/api/v1/users`
- **HTTP Method:** POST
- **Description:** Add a new user.
- **Request Parameters:**
  - `username` (string)
  - `password` (string)
- **Response:**
  - Success (201): User added successfully.
  - Bad Request (400):
    - Missing username or password.
    - Password not in SHA1 format.
  - Method Not Allowed (405).

### 2. Remove User

- **Endpoint:** `/api/v1/users/<username>`
- **HTTP Method:** DELETE
- **Description:** Remove a user by username.
- **Request Parameters:**
  - `username` (string)
- **Response:**
  - Success (200): User removed successfully.
  - Bad Request (400): User doesn't exist.
  - Method Not Allowed (405).

### 3. List All Users

- **Endpoint:** `/api/v1/users`
- **HTTP Method:** GET
- **Description:** List all users.
- **Request Parameters:** None
- **Response:**
  - Success (200): List of usernames.
  - No Content (204): No users exist.
  - Method Not Allowed (405).

### 4. List Dynamo Db Users

- **Endpoint:** `/api/v1/users/dynamo`
- **HTTP Method:** GET
- **Description:** List all users.
- **Request Parameters:** None
- **Response:**
  - Success (200): List of usernames.
  - No Content (204): No users exist.
  - Method Not Allowed (405).  

### 5. Home

- **Endpoint:** `/`
- **HTTP Method:** GET
- **Description:** Home page.
- **Request Parameters:** None
- **Response:** A simple welcome message.

