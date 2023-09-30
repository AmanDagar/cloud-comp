# cloud-comp
A simple flask app that can be deployed to AWS using Terraform and Docker. SQLite3 embedded database is used to store data.

Make sure you've installed terraform and you've copied the AWS CLI credentials to '~/.aws/credentials' before running

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

