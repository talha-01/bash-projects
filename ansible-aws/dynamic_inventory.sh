#!/bin/bash
echo '''
This script creates managed nodes asking the number from the user, and
puts the instances in a file named `inventory` in the same directory.
Key-pair location is set `~/.aws/keys/`. 

Requirements: AWS CLI, AWS Configuration
Key-Pair Location: ~/.aws/keys
'''


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

read -p "Do you want to use one of them? [y/n] _ " res

if [ $res == y ]
then
    count=1
    for sgroup in $security_groups;
    do
        echo "$count- $sgroup"
        let count++
    done 
    read -p "Please enter the order number of your preferred security group: _ " pref
    security_group=${groups_array[$pref]}
    echo "You entered $security_group"
    sleep 2
    clear
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
        for key in ${keys_array[*]};
        do
            echo "$count- $key"
            let count++
        done
        echo $keys_array
        read -p "Please enter the order number of one key-pair _ " order
        key_name=${keys_array[$order]}
        clear
        sleep 1
    else
        read -p "Please enter a name for your new key-pair _ " key_name
        aws ec2 create-key-pair --key-name $key_name --query 'KeyMaterial' --output text > ~/.aws/keys/$key_name.pem
        chmod 400 ~/.aws/keys/$key_name.pem
    fi
fi

read -p "Please the enter the number of instances you want to create _ " num
for (( i=1; i<=$num; i++ ))
do
aws ec2 run-instances \
--image-id ami-0947d2ba12ee1ff75 \
--count 1 \
--instance-type t2.micro \
--key-name $key_name \
--security-groups $security_group \
--tag-specifications "ResourceType=instance,Tags=[{Key=Ansible,Value=Node${i}}]" > /dev/null
done
echo "Nodes are created"
dns_names=()
count=1
while :
do
    for (( i=1; i<=$num; i++ ))
    do
        dns_name=$(aws ec2 describe-instances --filter "Name=tag:Ansible,Values=Node${i}" --query=Reservations[*].Instances[*].[PublicDnsName] --output text)
        dns_names[$count]=$dns_name
        let count++
    done
    if [[ ${#dns_names[*]} -eq $num ]]
    then
        break
    fi
done
count=1
echo '[webservers]' > $(pwd)/inventory
for node in ${dns_names[*]}
do
    node=${dns_names[$count]}
    echo """Node$count ansible_host=$(echo $node | tr -d "[:space:]") ansible_user=ec2-user ansible_ssh_private_key_file=~/.aws/keys/$key_name.pem""" >> $(pwd)/inventory
    let count++
done
rm -rf key_pairs.txt
echo "Inventory is created successfully\n"
echo "File location ::: $(pwd)/inventory\n"
echo "Listing your nodes"
ansible -i $(pwd)/inventory all --list-hosts
