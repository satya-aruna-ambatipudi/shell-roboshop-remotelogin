#!/bin/bash

# color codes in Linux, can be enabled with echo -e option
R='\e[31m'
G='\e[32m'
Y='\e[33m'
N='\e[0m'

SCRIPT_DIR=$PWD # special variable for present working directory
USERID=$(id -u) # userid of root user 0, and others non-zero
LOGS_FOLDER="/var/log/shell-roboshop"
LOGS_FILE="$LOGS_FOLDER/$(basename $0).log"
MONGODB_HOST="mongodb.asadaws2026.online"

if [ $USERID -ne 0 ]; then
    echo -e "$R Please run this script with root user access $N" 
    exit 1 # we need to exit with failure exit code
fi

mkdir -p $LOGS_FOLDER

ORIGINAL_HOME=$(eval echo "~$SUDO_USER")

# Functions are not executed by default, only executed when called
VALIDATE()
{
    if [ $1 -ne 0 ]; then
        echo -e "$2 ...$R FAILURE $N" | tee -a $LOGS_FILE
        exit 1
    else
        echo -e "$2 ...$G SUCCESS $N" | tee -a $LOGS_FILE
    fi
}

dnf module disable nodejs -y &>> $LOGS_FILE
VALIDATE $? "Disabling Nodejs default version"

dnf module enable nodejs:20 -y &>> $LOGS_FILE
VALIDATE $? "Enabling Nodejs version 20"

dnf install nodejs -y &>> $LOGS_FILE
VALIDATE $? "Installing Nodejs"

id roboshop &>> $LOGS_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop  &>> $LOGS_FILE
    VALIDATE $? "Creating Application User"
else
    echo -e "Roboshop user already exists...$Y SKIPPING $N" | tee -a $LOGS_FILE
fi

rm -rf /app
VALIDATE $? "Remove the /app directory if already exists"

mkdir -p /app 
VALIDATE $? "Creating Application directory"

curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>> $LOGS_FILE
VALIDATE $? "Downloading Application code to temp directory"

cd /app
VALIDATE $? "Go to Application directory"

unzip /tmp/catalogue.zip  &>> $LOGS_FILE
VALIDATE $? "Unzip the application code"

npm install  &>> $LOGS_FILE
VALIDATE $? "Install dependencies"

cp $ORIGINAL_HOME/catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? "Setup Systemd catalogue service for systemctl"

systemctl daemon-reload
VALIDATE $? "Reload the newly created systemd catlogue service"

systemctl enable catalogue &>> $LOGS_FILE
VALIDATE $? "Enable catalogue service"

systemctl start catalogue
VALIDATE $? "Start catalogue service"

cp $ORIGINAL_HOME/mongodb.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "Setup mongodb repo"

dnf install mongodb-mongosh -y &>> $LOGS_FILE
VALIDATE $? "Installing mongodb client"

if [ $(mongosh --host $MONGODB_HOST --eval 'db.getMongo().getDBNames().indexOf("catalogue")' --quiet) -lt 0 ]; then
    mongosh --host $MONGODB_HOST </app/db/master-data.js &>> $LOGS_FILE
    VALIDATE $? "Loading the catalogue data into MongoDB"
else
    echo -e "Catalogue database already exists... $Y SKIPPING $N"
fi

systemctl restart catalogue
VALIDATE $? "Restart catalogue service"