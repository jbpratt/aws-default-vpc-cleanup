from typing import Dict, Optional
import boto3  # type: ignore
from botocore.exceptions import ClientError  # type: ignore


def main() -> None:
    for region in boto3.client("ec2").describe_regions().get("Regions", {}):
        print(f"starting in {region}")

        ec2_client = boto3.client("ec2", region_name=region.get("RegionName"))
        try:
            acct_attr_res: Dict = ec2_client.describe_account_attributes(
                AttributeNames=["default-vpc"]
            )
        except ClientError as error:
            raise error

        vpc_id: Optional[str] = acct_attr_res.get("AccountAttributes", {})[0].get(
            "AttributeValues", {}
        )[0].get("AttributeValue")
        if vpc_id is None:
            print(f"no default vpc found in {region}")
            continue

        try:
            igw_res: Dict = ec2_client.describe_internet_gateways(
                Filters=[{"Name": "attachment.vpc-id", "Values": [vpc_id]}]
            )
        except ClientError as error:
            raise error

        for igw in igw_res.get("InternetGateways", {}):
            try:
                ec2_client.detach_internet_gateway(
                    InternetGatewayId=igw.get("InternetGatewayId"), VpcId=vpc_id
                )
            except ClientError as error:
                raise error

            print(f"detached {igw}")
            try:
                ec2_client.delete_internet_gateway(
                    InternetGatewayId=igw.get("InternetGatewayId")
                )
            except ClientError as error:
                raise error

            print(f"deleted {igw}")

        try:
            subnets: Dict = ec2_client.describe_subnets(
                Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
            )
        except ClientError as error:
            raise error

        for subnet in subnets.get("Subnets", {}):
            try:
                ec2_client.delete_subnet(SubnetId=subnet.get("SubnetId"))
            except ClientError as error:
                raise error

            print(f"deleted {subnet}")

        try:
            rt_res: Dict = ec2_client.describe_route_tables(
                Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
            )
        except ClientError as error:
            raise error

        for route_table in rt_res.get("RouteTables", {}):
            if not route_table.get("Associations", {})[0].get("Main"):
                try:
                    ec2_client.delete_route_table(
                        RouteTableId=route_table.get("RouteTableId")
                    )
                except ClientError as error:
                    raise error

                print(f"deleted {route_table}")

        try:
            acls_res: Dict = ec2_client.describe_network_acls(
                Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
            )
        except ClientError as error:
            raise error

        for acl in acls_res.get("NetworkAcls", {}):
            if not acl.get("IsDefault"):
                try:
                    ec2_client.delete_network_acl(NetworkAclId=acl.get("NetworkAclId"))
                except ClientError as error:
                    raise error

                print(f"deleted {acl}")

        try:
            sec_grps_res: Dict = ec2_client.describe_security_groups(
                Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
            )
        except ClientError as error:
            raise error

        for sec_group in sec_grps_res.get("SecurityGroups", {}):
            if not sec_group.get("GroupName") == "default":
                try:
                    ec2_client.delete_security_group(GroupId=sec_group.get("GroupId"))
                except ClientError as error:
                    raise error

                print(f"deleted {sec_group}")

        try:
            dhcp_opt_res: Dict = ec2_client.describe_dhcp_options(
                Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
            )
        except ClientError as error:
            raise error

        for dhcp_opt in dhcp_opt_res.get("DhcpOptions", {}):
            try:
                ec2_client.delete_dhcp_options(
                    DhcpOptionsId=dhcp_opt.get("DhcpOptionsId")
                )
            except ClientError as error:
                raise error

            print(f"deleted {dhcp_opt}")

        try:
            ec2_client.delete_vpc(VpcId=vpc_id)
        except ClientError as error:
            raise error

        print(f"deleted {vpc_id}")


if __name__ == "__main__":
    main()
