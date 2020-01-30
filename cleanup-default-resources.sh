#!/bin/bash

function delete_igw() {
	local region=$1
	local vpc=$2
	igws=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values="${vpc}" --region "${region}" | jq '.InternetGateways | .[] | .InternetGatewayId' | tr -d '"')
	if [ -n "$igws" ]; then
		for igw_id in $igws; do
			if aws ec2 detach-internet-gateway --internet-gateway-id "${igw_id}" --vpc-id "${vpc}" --region "${region}"; then
				echo "detached ${igw_id} from ${vpc}"
				aws ec2 delete-internet-gateway --internet-gateway-id "${igw_id}" --region "${region}"
				echo "deleted ${igw_id}"
			fi
		done
	fi

}

function delete_subnets() {
	local region=$1
	local vpc=$2
	subnets=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="${vpc}" --region "${region}" | jq '.[] | .[].SubnetId' | tr -d '"')
	for subnet_id in $subnets; do
		aws ec2 delete-subnet --subnet-id "${subnet_id}" --region "${region}"
		echo "deleted ${subnet_id}"
	done
}

function delete_route_tables() {
	local region=$1
	local vpc=$2
	rts=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values="${vpc}" --region "${region}" | jq '.RouteTables | .[].Associations | .[] | select(.Main != true) | .RouteTableId' | tr -d '"')
	for rt_id in $rts; do
		aws ec2 delete-route-table --route-table-id "${rt_id}" --region "${region}"
		echo "deleted ${rt_id}"
	done
}

function delete_acls() {
	local region=$1
	local vpc=$2
	acls=$(aws ec2 describe-network-acls --filters Name=vpc-id,Values="${vpc}" --region "${region}" | jq '.NetworkAcls | .[] | select(.IsDefault != true) | .NetworkAclId' | tr -d '"')
	for acl_id in $acls; do
		aws ec2 delete-network-acl --network-acl-id "${acl_id}" --region "${region}"
		echo "deleted ${acl_id}"
	done
}

function delete_security_groups() {
	local region=$1
	local vpc=$2
	sgps=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="${vpc}" --region "${region}" | jq '.SecurityGroups | .[] | select(.GroupName != "default") | .GroupId' | tr -d '"')
	for sgp_id in $sgps; do
		aws ec2 delete-security-group --group-id "${sgp_id}" --region "${region}"
		echo "deleted ${sgp_id}"
	done
}

function delete_dhcp_options() {
	local region=$1
	dhcp_ops=$(aws ec2 describe-dhcp-options --filters "Name=key,Values=domain-name-servers,Name=value,Values=AmazonProvidedDNS" --region "${region}" | jq '.DhcpOptions | .[] | .DhcpOptionsId' | tr -d '"')
	for dhcp_ops_id in $dhcp_ops; do
		aws ec2 delete-dhcp-options --dhcp-options-id "${dhcp_ops_id}" --region "${region}"
		echo "deleted ${dhcp_ops_id}"
	done
}

function delete_vpc() {
	local region=$1
	local vpc=$2
	aws ec2 delete-vpc --vpc-id "${vpc}" --region "${region}"
	echo "deleted ${vpc}"
}

regions=$(aws ec2 describe-regions | jq '.[] | .[].RegionName' | tr -d '"')

if [[ $(aws sts get-caller-identity 2> >(grep -c 'invalid')) -eq 1 ]]; then
	exit
fi

for region in $regions; do
	echo "starting ${region}..."
	vpc_id=$(aws ec2 describe-account-attributes --attribute-name default-vpc \
		--region "${region}" | jq '.AccountAttributes | .[].AttributeValues | .[] | .AttributeValue' | tr -d '"')

	if [ "${vpc}" == "none" ]; then
		echo "no default vpc to delete"
		echo "moving on..."

		echo "attempting to delete left over DHCP options for good measure"
		delete_dhcp_options "${region}" "${vpc_id}"
	fi
	echo "detaching and deleting igw..."
	delete_igw "${region}" "${vpc_id}"
	echo "deleting subnets..."
	delete_subnets "${region}" "${vpc_id}"
	echo "deleting rts..."
	delete_route_tables "${region}" "${vpc_id}"
	echo "deleting acls..."
	delete_acls "${region}" "${vpc_id}"
	echo "deleting security groups..."
	delete_security_groups "${region}" "${vpc_id}"
	echo "deleting vpc (${vpc_id})..."
	delete_vpc "${region}" "${vpc_id}"
	echo "deleting left over DHCP options"
	delete_dhcp_options "${region}" "${vpc_id}"
done

# get account atrributes
#  1.) Delete the internet gateway
#  2.) Delete subnets
#  3.) Delete route tables
#  4.) Delete network access lists
#  5.) Delete security groups
#  6.) Delete the VPC
