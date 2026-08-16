#!/bin/bash

# color codes in Linux, can be enabled with echo -e option
R='\e[31m'
G='\e[32m'
Y='\e[33m'
N='\e[0m'


USERID=$(id -u) # userid of root user 0, and others non-zero
LOGS_FOLDER="/var/log/shell-roboshop"
LOGS_FILE="$LOGS_FOLDER/$0.log"

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

dnf module disable redis -y &>> $LOGS_FILE
VALIDATE $? "Disabling Redis default version"

dnf module enable redis:7 -y &>> $LOGS_FILE
VALIDATE $? "Enabling Redis version 7"

dnf install redis -y &>> $LOGS_FILE
VALIDATE $? "Installing Redis"

# sed -i 's/127.0.0.1/0.0.0.0/g' /etc/redis/redis.conf
# VALIDATE $? "redis.conf change to allow all connections (::1)"

# sed -i 's/protected-mode yes/protected-mode no/g' /etc/redis/redis.conf
# VALIDATE $? "redis.conf change protected-mode to no"

# making all config changes at the same time using sed
sed -i -e 's/127.0.0.1/0.0.0.0/g' -e '/protected-mode/ c protected-mode no' /etc/redis/redis.conf
VALIDATE $? "redis.conf change to allow all connections and disable protected-mode"

systemctl enable redis &>> $LOGS_FILE
VALIDATE $? "Enable redis"

systemctl start redis 
VALIDATE $? "Start redis"

