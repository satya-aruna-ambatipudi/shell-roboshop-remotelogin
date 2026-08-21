#!/bin/bash

# color codes in Linux, can be enabled with echo -e option
R='\e[31m'
G='\e[32m'
Y='\e[33m'
N='\e[0m'

LOGS_FOLDER="/var/log/shell-roboshop"
LOGS_FILE="$LOGS_FOLDER/$(basename $0).log"

source ./roboshop.sh

mkdir -p $LOGS_FOLDER

#nohup sudo sh ./roboshop.sh mongodb &>> $LOGS_FILE &
nohup sudo sh ./roboshop.sh redis &>> $LOGS_FILE &
nohup sudo sh ./roboshop.sh mysql &>> $LOGS_FILE &
nohup sudo sh ./roboshop.sh rabbitmq &>> $LOGS_FILE &
#nohup sudo sh ./roboshop.sh catalogue &>> $LOGS_FILE &
nohup sudo sh ./roboshop.sh user &>> $LOGS_FILE &
nohup sudo sh ./roboshop.sh cart &>> $LOGS_FILE &
nohup sudo sh ./roboshop.sh payment &>> $LOGS_FILE &
nohup sudo sh ./roboshop.sh shipping &>> $LOGS_FILE &
nohup sudo sh ./roboshop.sh frontend &>> $LOGS_FILE &