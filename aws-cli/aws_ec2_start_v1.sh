#!/bin/bash
if [ "$1" ]
then
    InstanceId=$(aws ec2 describe-instances --filter Name=tag-key,\
    Values=Name --query 'Reservations[*].Instances[*].{Instance:InstanceId,Name:Tags[?Key==`Name`]|[0].Value}' | \
    grep $1 -B1 | head -1 | cut -d'"' -f4 )
    aws ec2 start-instances --instance-ids $InstanceId
else
    ins_array=()
    aws ec2 describe-instances --filter Name=tag-key,Values=Name --query 'Reservations[*].Instances[*].{Instance:InstanceId,Name:Tags[?Key==`Name`]|[0].Value}' > ins_names.txt
    count=1
    while read line
    do
        instanceId=$( echo "$line" | grep Instance | cut -d'"' -f4 ) 
        if [ "$instanceId" ];
        then
            ins_array[$count]=$instanceId
            echo -n "$count- $instanceId"
        fi
        name=$( echo "$line" | grep Name | cut -d'"' -f4 )
        if [ "$name" ];
        then
            echo --- "$name"
            let count++
        fi
    done < ins_names.txt

    if [ ${#ins_array[*]} -gt 0 ];
    then
        echo "You have ${#ins_array[*]} instances."
        read -p "Which one do you want to start? Please enter the order number _ " order
        aws ec2 start-instances --instance-ids ${ins_array[$order]}
    else
        echo "You don't have any instances"
        echo "Calling ec2_launch command"
        bash ec2_launch.sh
    fi
fi