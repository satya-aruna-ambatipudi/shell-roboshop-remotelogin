#!/bin/bash

SG_ID="sg-03593bef1b85c5110"    # Security group ID  taken from AWS console
AMI_ID="ami-0220d79f3f480ecf5"  # AMI ID taken from AWS console
INSTANCE_TYPE="t3.micro"
HOSTED_ZONEID="Z035824316LQSIE0W55SY"
DOMAIN_NAME="asadaws2026.online"
KEY_PATH="$HOME/.ssh/id_automation"
SCRIPT_DIR=$PWD

# 1. Generate SSH Key only if it doesn't exist
if [ ! -f "$KEY_PATH" ]; then
    echo "Generating automation SSH key..."
    ssh-keygen -t rsa -N "" -f "$KEY_PATH"
fi

# Extract the public key string to a variable
#PUB_KEY=$(cat "${KEY_PATH}.pub")

# import the keypair into aws
aws ec2 import-key-pair \
    --key-name "id_automation" \
    --public-key-material fileb://"${KEY_PATH}.pub"

for instance in $@
do
    INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --security-group-ids $SG_ID \
    --key-name "id_automation" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query 'Instances[0].InstanceId' \
    --output text)   

    if [ $instance == "frontend" ]; then
        IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[*].Instances[*].[PublicIpAddress]' \
        --output text)
        RECORD_NAME="$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[*].Instances[*].[PrivateIpAddress]' \
        --output text)
        RECORD_NAME="$instance.$DOMAIN_NAME"
    fi

    echo "IP address: $IP"

    aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONEID" \
    --change-batch '
    {
    "Comment": "Update record to reflect new IP address",
    "Changes": [
        {
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "'$RECORD_NAME'",
            "Type": "A",
            "TTL": 1,
            "ResourceRecords": [
            {
                "Value": "'$IP'"
            }
            ]
        }
        }
    ]
    }'

    echo "Record updated for $instance"

    # Copy the service file
    scp -i $KEY_PATH $SCRIPT_DIR/$instance.service ec2-user@$IP:~/

    # Copy the script
    scp -i $KEY_PATH $SCRIPT_DIR/$instance.sh ec2-user@$IP:~/

    #ssh -i $KEY_PATH $SCRIPT_DIR/$instance.sh ec2-user@$IP << 'EOF'
    ssh -i "$KEY_PATH" ec2-user@"$IP" "sudo sh ~/$instance.sh"


done