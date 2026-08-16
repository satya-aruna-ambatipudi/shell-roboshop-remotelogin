#!/bin/bash

# color codes in Linux, can be enabled with echo -e option
R='\e[31m'
G='\e[32m'
Y='\e[33m'
N='\e[0m'

SCRIPT_DIR=$PWD # special variable for present working directory
USERID=$(id -u) # userid of root user 0, and others non-zero
LOGS_FOLDER="/var/log/shell-roboshop"
LOGS_FILE="$LOGS_FOLDER/$0.log"
MYSQL_HOST=mysql.asadaws2026.online
MYSQL_USER=root
MYSQL_PASSWD=RoboShop@1

if [ $USERID -ne 0 ]; then
    echo -e "$R Please run this script with root user access $N" | tee -a $LOGS_FILE
    exit 1 # we need to exit with failure exit code
fi

mkdir -p $LOGS_FOLDER

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

dnf install maven -y &>> $LOGS_FILE
VALIDATE $? "Installing maven"

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

curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip  &>> $LOGS_FILE
VALIDATE $? "Downloading Application code to temp directory"

cd /app
VALIDATE $? "Go to Application directory"

unzip /tmp/shipping.zip  &>> $LOGS_FILE
VALIDATE $? "Unzip the application code"

mvn clean package  &>> $LOGS_FILE
VALIDATE $? "Download dependencies and build the application"

mv target/shipping-1.0.jar shipping.jar
VALIDATE $? "Moving the target application to parent folder"

cp $SCRIPT_DIR/shipping.service /etc/systemd/system/shipping.service
VALIDATE $? "Setup Systemd shipping service for systemctl"

systemctl daemon-reload
VALIDATE $? "Reload the newly created systemd shipping service"

systemctl enable shipping &>> $LOGS_FILE
VALIDATE $? "Enable shipping service"

systemctl start shipping
VALIDATE $? "Start shipping service"

dnf install mysql -y  &>> $LOGS_FILE
VALIDATE $? "Installing mysql client"

mysql -h $MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWD < /app/db/schema.sql
VALIDATE $? "Load Schema in mysql database"

mysql -h $MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWD < /app/db/app-user.sql 
VALIDATE $? "Creating app user in mysql database"

mysql -h $MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWD < /app/db/master-data.sql
VALIDATE $? "Loading the Master data for shipping"

systemctl restart shipping
VALIDATE $? "Restart shipping service"