#!/bin/bash
aws ec2 create-security-group --group-name $1 \
--description TCP-http-https-icmp --vpc-id vpc-88ae95f2

echo " "
echo "You created security group - $1 -"
read -p "Which ports do you want to open? Enter the port numbers _ " ports

for port in $ports;
do
    aws ec2 authorize-security-group-ingress --group-name $1 \
--protocol tcp --port $port --cidr "0.0.0.0/0"
done
clear
echo '*********************************************************'
echo 
echo "Security group $1 has been created per your instructions!"
echo
echo '*********************************************************'

