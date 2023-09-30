#getting base image
FROM alpine:3.7

RUN apk add --no-cache python3

RUN pip3 install --upgrade pip

WORKDIR /users

COPY . /users

RUN pip3 install boto3

RUN pip3 install Flask

RUN pip3 install Flask-Cors

RUN pip3 install requests

EXPOSE 80

ENV DYNAMODB_TABLE_NAME="FlaskAppTable"

ENTRYPOINT ["python3"]

CMD ["user_mgmt_app.py"]
