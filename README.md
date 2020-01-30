# AWS Default VPC Cleanup

This cleans up existing default VPC resources on new accounts that are provisioned on creation. Simply executing the script will query out to the EC2 service (each region, one at a time) grabbing the default VPC ID and pass it along with every request made to the cli, ensuring we are deleting only resources associated it.

Order of operations:
1. Delete the internet gateway
2. Delete subnets
3. Delete route tables
4. Delete network access lists
5. Delete security groups
6. Delete the VPC
7. Delete left over DHCP options
