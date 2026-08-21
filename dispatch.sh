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
    echo -e "$R Please run this script with root user access $N" | tee -a $LOGS_FILE
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

dnf install golang -y &>> $LOGS_FILE
VALIDATE $? "Installing GoLang"

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

curl -L -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch-v3.zip  &>> $LOGS_FILE
VALIDATE $? "Downloading Application code to temp directory"

cd /app
VALIDATE $? "Go to Application directory"

unzip /tmp/dispatch.zip &>> $LOGS_FILE
VALIDATE $? "Unzip the application code"

go mod init dispatch  &>> $LOGS_FILE
VALIDATE $? "Initializing the dispatch module"

go get  &>> $LOGS_FILE
VALIDATE $? "Download and install dependencies"

go build  &>> $LOGS_FILE
VALIDATE $? "Build the dispatch application"

cp $ORIGINAL_HOME/dispatch.service /etc/systemd/system/dispatch.service
VALIDATE $? "Setup Systemd dispatch service for systemctl"

systemctl daemon-reload
VALIDATE $? "Reload the newly created systemd dispatch service"

systemctl enable dispatch &>> $LOGS_FILE
VALIDATE $? "Enable dispatch service"

systemctl start dispatch
VALIDATE $? "Start dispatch service"