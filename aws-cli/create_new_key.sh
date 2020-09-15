#!/bin/bash

aws ec2 describe-key-pairs > key_pairs.txt

keys_array=()
count=0
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
    
    read -p "Do you want to use one of your current key-pairs? [y/n] _ " res

    if [ $res == y ];
    then
        read -p "Please enter the order number of one key-pair _ " order
        key_pair=${keys_array[$order]}
    else
        read -p "Please enter a name for your new key-pair _ " name
        aws ec2 create-key-pair --key-name $name --query 'KeyMaterial' --output text > ~/.aws/keys/$name.pem
    fi
else
    aws ec2 create-key-pair --key-name $1 --query 'KeyMaterial' --output text > ~/.aws/keys/$1.pem
fi