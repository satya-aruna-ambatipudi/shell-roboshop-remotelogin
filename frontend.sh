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

dnf module disable nginx -y &>> $LOGS_FILE
VALIDATE $? "Disabling Nginx default version"

dnf module enable nginx:1.24 -y &>> $LOGS_FILE
VALIDATE $? "Enabling Nginx version 1.24"

dnf install nginx -y &>> $LOGS_FILE
VALIDATE $? "Installing Nginx"

systemctl enable nginx  &>> $LOGS_FILE
VALIDATE $? "Enable Nginx service"

systemctl start nginx 
VALIDATE $? "Start Nginx service"

rm -rf /usr/share/nginx/html/* 
VALIDATE $? "Remove the default contentent of web server"

curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>> $LOGS_FILE
VALIDATE $? "Download the frontend content"

cd /usr/share/nginx/html 
VALIDATE $? "Go to html folder"

unzip /tmp/frontend.zip &>> $LOGS_FILE
VALIDATE $? "Unzip the frontend content"

cp $ORIGINAL_HOME/nginx.conf /etc/nginx/nginx.conf
VALIDATE $? "Create Nginx Reverse Proxy Configuration"

systemctl restart nginx 
VALIDATE $? "Restart nginx service after reverse proxy configuration"
