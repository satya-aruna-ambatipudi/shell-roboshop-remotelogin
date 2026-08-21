#!/bin/bash

SG_ID="sg-03593bef1b85c5110"    # Security group ID taken from AWS console
AMI_ID="ami-0220d79f3f480ecf5"  # AMI ID taken from AWS console
INSTANCE_TYPE="t3.micro"
HOSTED_ZONEID="Z035824316LQSIE0W55SY"
DOMAIN_NAME="asadaws2026.online"
KEY_PATH="$HOME/.ssh/id_automation"
SCRIPT_DIR=$PWD
SSH_USER="ec2-user" 

# 1. Generate SSH Key only if it doesn't exist
if [ ! -f "$KEY_PATH" ]; then
    echo "Generating automation SSH key..."
    ssh-keygen -t rsa -b 3072 -N "" -f "$KEY_PATH"
    chmod 600 "$KEY_PATH"
fi

# Cleanly read the public key contents
PUB_KEY_CONTENT=$(cat "${KEY_PATH}.pub")

# 2. Import the keypair safely into AWS
aws ec2 describe-key-pairs --key-names "id_automation" &>/dev/null || \
aws ec2 import-key-pair \
    --key-name "id_automation" \
    --public-key-material fileb://"${KEY_PATH}.pub"

# 3. Write a dynamic script file to pass into user-data cleanly
# UPDATED: Injected RHEL 9 SSH password authentication disabling logic into first-boot user-data
cat << EOF > user_data_script.sh
#!/bin/bash
# Set up secure key directories
mkdir -p /home/${SSH_USER}/.ssh
echo "${PUB_KEY_CONTENT}" > /home/${SSH_USER}/.ssh/authorized_keys
chmod 700 /home/${SSH_USER}/.ssh
chmod 600 /home/${SSH_USER}/.ssh/authorized_keys
chown -R ${SSH_USER}:${SSH_USER} /home/${SSH_USER}/.ssh

# Harden SSH: Disable Password and Keyboard-Interactive Auth for RHEL 9
mkdir -p /etc/ssh/sshd_config.d

cat << 'INNER_EOF' > /etc/ssh/sshd_config.d/49-disable-passwords.conf
PasswordAuthentication no
KbdInteractiveAuthentication no
INNER_EOF

# Remove weaker configuration fallbacks if cloud-init generated them
rm -f /etc/ssh/sshd_config.d/50-disable-passwords.conf

# Reload the SSH daemon to enforce rules safely without disconnecting boot hooks
if sshd -t; then
    systemctl reload sshd
fi
EOF

for instance in $@
do
    echo "--------------------------------------------"
    echo "Launching instance: $instance"
    echo "--------------------------------------------"
    
    # Launching with a clean file-read parameter for user data
    INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --security-group-ids $SG_ID \
    --key-name "id_automation" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --user-data file://user_data_script.sh \
    --query 'Instances[0].InstanceId' \
    --output text)   

    echo "Waiting for instance $INSTANCE_ID to enter running state..."
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

    # Use PrivateIpAddress everywhere since your script runs from instance 172.31.25.53
    IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[*].Instances[*].[PrivateIpAddress]' \
    --output text)

    if [ "$instance" == "frontend" ]; then
        RECORD_NAME="$DOMAIN_NAME"
    else
        RECORD_NAME="$instance.$DOMAIN_NAME"
    fi

    echo "Target internal IP: $IP"

    # Route53 record tracking
    aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONEID" \
    --change-batch "
    {
    \"Comment\": \"Update record to reflect new IP address\",\
    \"Changes\": [
        {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
            \"Name\": \"$RECORD_NAME\",\
            \"Type\": \"A\",\
            \"TTL\": 1,\
            \"ResourceRecords\": [
            {
                \"Value\": \"$IP\"\
            }
            ]
        }
        }
    ]
    }"
    echo "Route53 record updated."

    # 4. Wait for SSH daemon to respond internally
    echo "Verifying internal port 22 access..."
    while ! nc -z -w 3 "$IP" 22; do
        sleep 2
    done
    
    # Give user-data script 5 seconds to finish writing permissions on boot
    sleep 5

    # 5. Execute file transfers
    echo "Transferring application configurations to $instance..."
    scp -o StrictHostKeyChecking=no -i "$KEY_PATH" "$SCRIPT_DIR/$instance."* $SSH_USER@"$IP":~/
   # scp -o StrictHostKeyChecking=no -i "$KEY_PATH" "$SCRIPT_DIR/$instance.sh" $SSH_USER@"$IP":~/

    # 6. Execute deployment
    echo "Initiating execution script on $instance..."
    ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" $SSH_USER@"$IP" "sudo sh ~/$instance.sh"

done

# Clean up local temporary file
rm -f user_data_script.sh
