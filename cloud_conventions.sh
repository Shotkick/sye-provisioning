#!/bin/bash

#set -euo pipefail

set -x
trap 'echo "[TRAP] Error on line $LINENO: command=\"$BASH_COMMAND\" exit_code=$?' ERR
trap 'echo "[TRAP] Executing line $LINENO: $BASH_COMMAND"' DEBUG
printf "DEBUG  Debug mode enabled\n"

#Check if script is run by root user
if [[ $EUID -ne 0 ]]; then
  printf "ERROR  This script must be run as root." >&2 #redirect to stderr
  exit 1
fi

declare -A USER_KEYS=(
  [eval]="ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGd1sEHWR+J1kz4TokLXzpTFGFO8dX3T1zWjQ0rJqsnrx1m8nTotpWTuqgQCgtIzQ8Usvy4wK3/pRV1raFtYThvEgHleB85YOaSiFEYs1rUz6KkQ8lhKuSXYLp8YnJtv0MCJNfm8jY816RvOqa+v7mS/+67ly4PXwf1jfibzw1bSZHc4w== snorwin@nano-x1"
  [djordjevic]="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9EFYu4SpUmaqLPhMlc2C3TdJhtbUqN/x8L9XUegnoxYo9OLdRmHQTIEuK7FpCatmYduInK4JzOB422gtnAOAgvwNN9/gsIdylcLBLnBtYNEKPUr8VR+PheMd3Q3MnV7wSd3oDXhntoRr9tDyvF+uNGXVArexnlNMRecHuNJQKI6+44CZQLiUOXMS3qyOFJ9o17EDmC8zIt0UwBskKuOzvi8t3uneVWvvxQLExXWES2vX3qwwmO1VN9XgmpglfW/MGp5QWfOMEzBF0iph0hzfyCxqISbf8BAVxGKzzcKQCSEDFO1x32cBkXIR8cniUcYqyCgz6y8LvTvcZchp1k0lx+WWsByHYyDX9Vty9PVRZkvvcVznRgY857/ueYj/bW6Mccprmd6FQ6ZrsbuGi4UWDJG7ok71AoreoZA1qHHVP2BUaYe60mjz7aDmOZ1KBl2oQznRqxO5c5nmczqtyW1vYwcb5gEFviSRkZMSMrbljkBnEVARbwCo0TdRsqtSfyThUfpLudzdtXzWsNcE1jZlW2KYQgqrRdVeSImn1slmjbT3VaJPcFN0GnaR7ThA9TIHizmxB+LN9I4RNxTVHNdOVGv7xD7voxZ2b6q2L+1BItnDTxCr7vXgZB/lGmR+XjF42mQCMYEmKexIW+P3Iv0BUtbi8uEaf/v8RLUmEMlAIZw== insy-switch-engines"
  [alsabti]="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDCr88QmTbghSTf3EESSn6adZbKIBBMr8Il8OXZfKCbWRMHGLBv1QtPftwbvCkbeKvH46P/hKU8HhSQO2HO6jCHgs8VG69h614zC0uVLNyQOlU6f2q3fazpQe8ckPpTQ1GwM5UPI8shOc4sS37b2dyo5NO+NRJqNqfvjRAmDtePVQ6bi3fx1ccTIe3lI9nE63cJQDh1gjOyknByNF/zfPY12sX9XvJW7ury1yY4XCd/cO3fh2ujSDcWALUJBm1JsDg39RVhbDZtLEuumB98FfMCWbpp0j/2O0fNO2wuKljYmub83Uim2/K2tg3T0Cix4kRtJlhbRzTzuvpvlpiTVBs1bLCT37zmfmNNoYSY7nyvcGLmSZKQYeGq9eu+EunX2OBKVZWEhi2OWFEdz5xmrahM3Nqcz12ha7qn80osh1JbNZjtckR5HAW1o5Lg9BMVc52PmiZJ2AAcN4znAX/Ond62v/f9ogx99uyEv7pN0W+3EvdEKlENB8WNiXDCihIozMv3pQdhyIUuFtZprADqtd0IBQ1tsGWWJWKTDduUXayR8wotUy/E+QaHXi4qPL6Yz8/wMv72L96IYjOQvrgB6wWDj9yzoedCweWxrwlhjqEaI1ayPHapx6S+WeucALka1XJA0enEk0YHQDKkpfz0sg4OTbrfNB1JIKHGXSdehupOw== insy-switch-engines"
)

createUser(){
    local username="$1"
    if userExists "$username"; then
        printf "SKIP  $username already exists\n"
    else
        printf "Creating $username:\n"
        adduser "$username"
        printf "OK  $username has been created\n"
    fi
}

userExists() {
    local username="$1"
    id "$username" &>/dev/null
}

addSudoUser(){
    local username="$1"
    local sudoersFile="/etc/sudoers.d/${username}"
    local sudoersLine="${username} ALL=(ALL) NOPASSWD:ALL"

    if [[ -f "$sudoersFile" ]] && grep -qF "$sudoersLine" "$sudoersFile"; then
        printf "SKIP  $username is already added in sudoers file\n"
    else
        echo "${username} ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/${username} > /dev/null
        chmod 0440 "$sudoersFile"
        printf "OK  $username sudoers file has been added\n"
    fi
}

setupUserSSH(){
    local username="$1"
    local key="$2"
    local sshDir="/home/${username}/.ssh"
    local authKeys="${sshDir}/authorized_keys"

    if [[ ! -d "$sshDir" ]]; then
        mkdir -p "$sshDir" #-p checks and creates parent folders if not existent
        printf "OK  .ssh directory for $username has been created\n"
    fi
    chmod 700 "$sshDir"
    chown "${username}:${username}" "$sshDir"

    if [[ -f "$authKeys" ]] && grep -qF "$key" "$authKeys"; then
        printf "SKIP  SSH key for $username already in authorized_keys\n"
    else
        echo "$key" >> "$authKeys"
        printf "OK  Added SSH key for $username.\n"
    fi

    chmod 600 "$authKeys"
    chown "${username}:${username}" "$authKeys"
}

for username in "${!USER_KEYS[@]}"; do #! = keys, not values
    createUser "$username"
    addSudoUser "$username"
    setupUserSSH "$username" "${USER_KEYS[$username]}"
done
printf "\n"
