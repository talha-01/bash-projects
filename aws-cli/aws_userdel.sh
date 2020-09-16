#!/bin/bash

read -p "Please enter aws users to be deleted _ " users
for user in $users
do
    echo "deleting login profile"
# deletes the login profile of the user
    aws iam delete-login-profile --user-name $user

    echo "deleting user's access keys"
# deletes the user's access keys
    aws iam list-access-keys --user-name $user > raw.json

    python -c "import json_converter as jc; jc.json_is_empty('raw.json')" > 1.txt
    if [ -s 1.txt ]
    then
        line=1
        python -c "import json_converter as jc; jc.json_converter('AccessKeyId')" | while read line
        do
            key=$line
            aws iam delete-access-key --user-name $user --access-key-id $key
        done
    else
        echo "  No access keys found for $user"
    fi

    echo "deleting user's signing certificate"
# deletes the user's signing certificate

    aws iam list-signing-certificates --user-name $user > raw.json

    python -c "import json_converter as jc; jc.json_is_empty('raw.json')" > 2.txt
    if [ -s 2.txt ]
    then
        line=1
        python -c "import json_converter as jc; jc.json_converter('CertificateId')" | while read line
        do
            key=$line
            aws iam delete-signing-certificate --user-name $user --certificate-id $key
        done
    else
        echo "  No signing certificate found for $user"
    fi

    echo "deleting user's SSH public key"
# deletes the user's SSH public key

    aws iam list-ssh-public-keys --user-name $user > raw.json

    python -c "import json_converter as jc; jc.json_is_empty('raw.json')" > 3.txt
    if [ -s 3.txt ]
    then
        line=1
        python -c "import json_converter as jc; jc.json_converter('SSHPublicKeyId')" | while read line
        do
            key=$line
            aws iam delete-ssh-public-key --user-name $user --ssh-public-key-id $key
        done
    else
        echo "  No SSH key found for $user"
    fi

    echo "deleting Git credentials"
# deletes the user's Git credentials

    aws iam list-service-specific-credentials --user-name $user > raw.json

    python -c "import json_converter as jc; jc.json_is_empty('raw.json')" > 4.txt
    if [ -s 4.txt ]
    then
        line=1
        python -c "import json_converter as jc; jc.json_converter('ServiceSpecificCredentiaId')" | while read line
        do
            key=$line
            aws iam delete-service-specific-credential --user-name $user --service-specific-credential-id $key
        done
    else
        echo "  No Git credentials found for $user"
    fi

    echo "deleting MFA device"
# deletes the user's multi-factor authentication (MFA) device

    aws iam list-mfa-devices --user-name $user > raw.json

    python -c "import json_converter as jc; jc.json_is_empty('raw.json')" > 5.txt
    if [ -s 5.txt ]
    then
        line=1
        python -c "import json_converter as jc; jc.json_converter('SerialNumber')" | while read line
        do
            key=$line
            aws iam deactivate-mfa-device --user-name $user --serial-number $key
            aws iam delete-virtual-mfa-device --serial-number $key
        done
    else
        echo "  No MFA device found for $user"
    fi

    echo "deleting inline policies"
# deletes the user's inline policies

    aws iam list-user-policies --user-name $user > raw.json

    code=$(cat << QQ
import json
with open ('raw.json', 'r') as json_file:
    json_data = json.load(json_file)
for key, value in json_data.items():
    if value:
        print(value[0])
QQ
)
    python -c "import json_converter as jc; jc.json_is_empty('raw.json')" > 6.txt
    if [ -s 6.txt ]
    then
        python -c "$code" | while read line
        do
            aws iam delete-user-policy --user-name $user --policy-name $line
        done
    else
        echo "  No inline policies found for $user"
    fi

    echo "detaching managed policies"
# detaches the user's managed policies

    aws iam list-attached-user-policies --user-name $user > raw.json

    python -c "import json_converter as jc; jc.json_is_empty('raw.json')" > 7.txt
    if [ -s 7.txt ]
    then
        python -c "import json_converter as jc; jc.json_converter('PolicyArn')" | while read line
        do
            arn=$line
            aws iam detach-user-policy --user-name $user --policy-arn $arn
        done
    else 
        echo "  No managed policies found for $user"
    fi

    echo "removing user from groups"
# removes the user from any groups

    aws iam list-groups-for-user --user-name $user > raw.json

    python -c "import json_converter as jc; jc.json_is_empty('raw.json')" > 8.txt
    if [ -s 8.txt ]
    then
        python -c "import json_converter as jc; jc.json_converter('GroupName')" | while read line
        do
            arn=$line
            aws iam remove-user-from-group --user-name $user --group-name $arn
        done
    else
        echo "  No groups found for $user"
    fi

    echo "removing the user"
# removes the user

    aws iam delete-user --user-name $user

    aws iam list-users > raw.json

    python -c "import json_converter as jc; jc.json_is_empty('raw.json')" | grep $user > 9.txt
    if [ -s 9.txt ]
    then
        echo "user $user not deleted"
        continue    
    fi
    echo "user $user deleted"

    sleep 1
done

rm -rf {1..9}.txt raw.json