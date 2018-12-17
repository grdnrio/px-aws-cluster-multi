vpc=$(aws ec2 create-vpc --cidr-block 192.168.99.0/24 | json Vpc.VpcId)
subnet=$(aws ec2 create-subnet --vpc-id $vpc --cidr-block 192.168.99.0/24 | json Subnet.SubnetId)
gw=$(aws ec2 create-internet-gateway | json InternetGateway.InternetGatewayId)
aws ec2 attach-internet-gateway --vpc-id $vpc --internet-gateway-id $gw
routetable=$(aws ec2 create-route-table --vpc-id $vpc | json RouteTable.RouteTableId)
aws ec2 create-route --route-table-id $routetable --destination-cidr-block 0.0.0.0/0 --gateway-id $gw
aws ec2 associate-route-table  --subnet-id $subnet --route-table-id $routetable
sg=$(aws ec2 create-security-group --group-name SSHAccess --description "Security group for SSH access" --vpc-id $vpc | json GroupId)
aws ec2 authorize-security-group-ingress --group-id $sg --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $sg --protocol tcp --port 32678 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $sg --protocol all --cidr 192.168.99.0/24

export subnet
export sg
