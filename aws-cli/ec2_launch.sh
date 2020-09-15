#!/bin/bash

security_groups=$( aws ec2 describe-security-groups \
| grep GroupName | cut -d'"' -f4 )

groups_array=()

count=1

for sgroup in $security_groups;
do
    groups_array[$count]=$sgroup
    let count++
done

echo "You have ${#groups_array[*]} security groups created before:"

count=1
for sgroup in $security_groups;
do
    echo "$count- $sgroup"
    let count++
done 

read -p "Do you want to use one of them? [y/n] _ " res

if [ $res == y ]
then
    read -p "Please enter the order number of your preferred security group: _ " pref
    security_group=${groups_array[$pref]}
    echo "You entered $security_group"
else
    read -p "Please enter a name for new security group" sg
    security_group=$(bash create_security_group.sh $sg)
fi

read -p "Do you want to use an existing key? [y/n] _ " res

if [ $res == n ]
then
    read -p "Please enter a name for your new key-pair _ " key_name
    aws ec2 create-key-pair --key-name $key_name --query 'KeyMaterial' --output text > ~/.aws/keys/$key_name.pem
    chmod 400 ~/.aws/keys/$name.pem
else
    aws ec2 describe-key-pairs > key_pairs.txt
    keys_array=()
    count=1
    while read line
    do
        data=$( echo "$line" | grep KeyName | cut -d'"' -f4 )
        
        if [ "$data" ];
        then
            keys_array[$count]=$data
            let count++
        fi
    done < key_pairs.txt

    if [ ${#keys_array[*]} -gt 0 ];
    then
        echo "You have ${#keys_array[*]} key-pairs: "
        
        count=1
        for key in $keys_array;
        do
            echo "$count- $key"
            let count++
        done
        read -p "Please enter the order number of one key-pair _ " order
        key_name=${keys_array[$order]}
    else
        read -p "Please enter a name for your new key-pair _ " key_name
        aws ec2 create-key-pair --key-name $key_name --query 'KeyMaterial' --output text > ~/.aws/keys/$key_name.pem
        chmod 400 ~/.aws/keys/$key_name.pem
    fi
fi

aws ec2 run-instances \
--image-id ami-0c94855ba95c71c99 \
--count 1 \
--instance-type t2.micro \
--key-name $key_name \
--security-groups $security_group