#!/bin/bash

# Define log and password files
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Create log and password files if they don't exist
touch $LOG_FILE
mkdir -p /var/secure
touch $PASSWORD_FILE

# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Function to generate random password
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12 ; echo ''
}

# Check if the input file is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

# Read the input file
INPUT_FILE=$1

# Check if the input file exists
if [ ! -f $INPUT_FILE ]; then
    echo "Input file not found!"
    exit 1
fi

while IFS=';' read -r username groups; do
    # Remove leading and trailing whitespaces
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    if id "$username" &>/dev/null; then
        log_message "User $username already exists. Skipping..."
        continue
    fi

    # Create a personal group for the user
    groupadd $username
    if [ $? -ne 0 ]; then
        log_message "Failed to create group $username."
        continue
    fi
    log_message "Group $username created successfully."

    # Create user and add to personal group
    useradd -m -g $username -s /bin/bash $username
    if [ $? -ne 0 ]; then
        log_message "Failed to create user $username."
        continue
    fi
    log_message "User $username created successfully."

    # Create additional groups if they don't exist and add user to groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo $group | xargs)
        if [ -z "$group" ]; then
            continue
        fi
        if ! getent group $group >/dev/null; then
            groupadd $group
            if [ $? -ne 0 ]; then
                log_message "Failed to create group $group."
                continue
            fi
            log_message "Group $group created successfully."
        fi
        usermod -aG $group $username
        log_message "User $username added to group $group."
    done

    # Set up home directory permissions
    chmod 700 /home/$username
    chown $username:$username /home/$username
    log_message "Permissions set for home directory of $username."

    # Generate random password and store it
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$username:$password" >> $PASSWORD_FILE
    log_message "Password set for user $username."

done < "$INPUT_FILE"

log_message "User and group creation process completed."

exit 0