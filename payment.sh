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

if [ $USERID -ne 0 ]; then
    echo -e "$R Please run this script with root user access $N" 
    exit 1 # we need to exit with failure exit code
fi

mkdir -p $LOGS_FOLDER
# 1. Dynamically discover the original user's home directory path
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

dnf install python3 gcc python3-devel -y &>> $LOGS_FILE
VALIDATE $? "Installing python3"

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

curl -L -o /tmp/payment.zip https://roboshop-artifacts.s3.amazonaws.com/payment-v3.zip  &>> $LOGS_FILE
VALIDATE $? "Downloading Application code to temp directory"

cd /app
VALIDATE $? "Go to Application directory"

unzip /tmp/payment.zip  &>> $LOGS_FILE
VALIDATE $? "Unzip the application code"

pip3 install -r requirements.txt  &>> $LOGS_FILE
VALIDATE $? "Download and install dependencies"

cp $ORIGINAL_HOME/payment.service /etc/systemd/system/payment.service
VALIDATE $? "Setup Systemd payment service for systemctl"

systemctl daemon-reload
VALIDATE $? "Reload the newly created systemd payment service"

systemctl enable payment &>> $LOGS_FILE
VALIDATE $? "Enable payment service"

systemctl start payment
VALIDATE $? "Start payment service"
