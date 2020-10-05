#!/bin/bash
echo '''
This script creates managed nodes asking the number from the user, and
puts the instances in a file named `inventory` in the same directory.
Key-pair location is set `~/.aws/keys/`.

Application uses free-tier eligible t2-micro and an us-east-1 region 
based ami.

Requirements: AWS CLI, AWS Configuration
Key-Pair Location: ~/.aws/keys
'''

ami="ami-0947d2ba12ee1ff75"

security_groups=$(aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupName]' --output text)

s_groups_array=()

count=1

for sgroup in $security_groups;
do
    s_groups_array[$count]=$sgroup
    let count++
done

echo "You have ${#s_groups_array[*]} security groups created before:"

read -p "Do you want to use one of your existing security groups? [y/n] _ " res

if [ $res == y ]
then
    count=1
    for sgroup in $security_groups;
    do
        echo "$count- $sgroup"
        let count++
    done 
    while :
    do
        read -p "Please enter the order number of your preferred security group: _ " pref
        
        if [ $pref -le ${#s_groups_array[*]} ]
        then 
            security_group=${s_groups_array[$pref]}
            echo "You entered $security_group"
            break
        else
            echo '''

            '''
            echo "You selected a number not existing in the list. Please check the number and try again. You can exit with CTRL+C"
        fi
    done
else

clear

    while :
    do        
        read -p "Please enter a name for new security group. [no_spaces] _ " sg_name
        read -p "Please enter a description for security group [space is allowed] _ " description
        read -p "Please enter port numbers [space required between port numbers] _ " ports

        aws ec2 create-security-group --group-name $sg_name \
        --description "$description" 1> /dev/null

        if [ $? -eq 0 ]
        then

            for port in $ports;
            do 
                echo """aws ec2 authorize-security-group-ingress --group-name $sg_name \
                --protocol tcp --port $port --cidr "0.0.0.0/0"
                """
            done

            security_group=$sg_name
            break

        else
            echo '''

            '''
            echo "An error occured. Please check the error message and try again. You can exit with CTRL+C"
        fi
    done
fi

read -p "Do you want to use an existing key? [y/n] _ " response

if [ $response == n ]
then
    read -p "Please enter a name for your new key-pair _ " key_name
    if [ ! -f ~/.aws/keys/ ]
    then
        mkdir -p ~/.aws/keys
    fi 
    aws ec2 create-key-pair --key-name $key_name --query 'KeyMaterial' --output text > ~/.aws/keys/$key_name.pem
    chmod 400 ~/.aws/keys/$key_name.pem
    key_location="~/.aws/keys/$key_name.pem"
    
else
    key_pairs=$(aws ec2 describe-key-pairs --query 'KeyPairs[*].[KeyName]' --output text)
    count=1
    for key in $key_pairs;
    do 
        if [ "$key" ];
        then
            keys_array[$count]=$key
            let count++
        fi
    done

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
        echo "No keys found ..."
        read -p "Please enter a name for your new key-pair _ " key_name
        aws ec2 create-key-pair --key-name $key_name --query 'KeyMaterial' --output text > ~/.aws/keys/$key_name.pem
        chmod 400 ~/.aws/keys/$key_name.pem
        key_location="~/.aws/keys/$key_name.pem"
    fi
fi

read -p "Please enter the number of instances you want to create _ " num
for (( i=1; i<=$num; i++ ))
do
    aws ec2 run-instances \
    --image-id $ami \
    --count 1 \
    --instance-type t2.micro \
    --key-name $key_name \
    --security-groups $security_group \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Ansible,Value=Node${i}}]" 1> /dev/null

    if [ ! $? -eq 0 ]; 
    then
        echo '''

        '''
        echo "Something went wrong. Exited"
        exit
    fi
done

clear
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
    node="${dns_names[$count]}"
    echo """node$count ansible_host=$(echo $node | tr -d "[:space:]") ansible_user=ec2-user ansible_ssh_private_key_file=~/.aws/keys/$key_name.pem""" >> $(pwd)/inventory
    let count++
done

echo "Inventory is created successfully"
echo "File location ::: $(pwd)/inventory"
echo "Listing your nodes"
ansible -i $(pwd)/inventory all --list-hosts
if [ "$key_location" ];
then
    echo "Your new key path is ::: $key_location"
fi