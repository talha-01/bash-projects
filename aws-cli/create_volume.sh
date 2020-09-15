#!/bin/bash

aws ec2 describe-instances > instances.txt
cat instances.txt | grep AvailabilityZone | cut -d'"' -f4 > az.txt
cat instances.txt | grep '"Key": "Name"' -A1 | grep Value | cut -d'"' -f4 > ins_names.txt
cat instances.txt | grep InstanceId | cut -d'"' -f4 > ins_ids.txt

instances=()

c1=1
while read line;
do
    instances[$c1]=$line
    let c1++
done < ins_names.txt

c2=1
while read line;
do
    instances[$c2]=${instances[$c2]}:$line
    let c2++
done < ins_ids.txt

c3=1
while read line;
do
    instances[$c3]=${instances[$c3]}:$line
    let c3++
done < az.txt

echo ${instances[*]}

 rm -f instances.txt az.txt ins_names.txt ins_ids.txt

echo "You have ${#instances[*]}" instances:
c4=1
for instance in "${instances[@]}";
do
    echo "$c4- $( echo $instance | tr : '\t' )"
    let c4++
done

read -p "Which instance do you want to attach the new volume _ " res1

InstanceName=$( echo ${instances[$res1]} | cut -d: -f1 )
InstanceId=$( echo ${instances[$res1]} | cut -d: -f2 )
AvailabilityZone=$( echo ${instances[$res1]} | cut -d: -f3 )

aws ec2 create-volume \
    --availability-zone $AvailabilityZone \
    --volume-type gp2 \
    --size 5 \
    --tag-specifications \
    "ResourceType=volume,Tags=[{Key=Name,Value=$InstanceName}]" > vol.txt

VolumeId=$( cat vol.txt | grep VolumeId | cut -d'"' -f4 )

sleep 5

aws ec2 attach-volume \
--volume-id $VolumeId \
--instance-id $InstanceId \
--device /dev/sdf