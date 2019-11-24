provider "aws" {
    region  = "ap-southeast-2"
}

resource "aws_vpc" "vpc" {
    cidr_block       = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
    
    tags = {
        Name = "Q-CRTL-VPC"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = "${aws_vpc.vpc.id}"

    tags = {
        Name = "Q-CTRL-IGW"
    }
}

resource "aws_subnet" "public_a" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-southeast-2a"

    tags = {
        Name = "Q-CTRL-PublicSubnetA"
    }
}

resource "aws_subnet" "public_b" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.2.0/24"
    availability_zone = "ap-southeast-2b"
    
    tags = {
        Name = "Q-CTRL-PublicSubnetB"
    }
}

resource "aws_route_table" "public_subnet_rt" {
    vpc_id = "${aws_vpc.vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.igw.id}"
    }

    tags = {
        Name = "Q-CTRL-PublicRouteTable"
    }
}

resource "aws_route_table_association" "public_subnet_a_association" {
    subnet_id = "${aws_subnet.public_a.id}"
    route_table_id = "${aws_route_table.public_subnet_rt.id}"
}

resource "aws_route_table_association" "public_subnet_b_association" {
    subnet_id = "${aws_subnet.public_b.id}"
    route_table_id = "${aws_route_table.public_subnet_rt.id}"
}

resource "aws_subnet" "private_a" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.3.0/24"
    availability_zone = "ap-southeast-2a"

    tags = {
        Name = "Q-CTRL-PrivateSubnetA"
    }
}

resource "aws_subnet" "private_b" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.4.0/24"
    availability_zone = "ap-southeast-2b"

    tags = {
        Name = "Q-CTRL-PrivateSubnetB"
    }
}

resource "aws_eip" "nat_gw_eip" {
    vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
    allocation_id = "${aws_eip.nat_gw_eip.id}"
    subnet_id = "${aws_subnet.public_a.id}"

    tags = {
        Name = "NatGW"
    }
}

resource "aws_route_table" "private_subnet_rt" {
    vpc_id = "${aws_vpc.vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_nat_gateway.nat_gw.id}"
    }

    tags = {
        Name = "Q-CTRL-PrivateSubnetRT"
    }
}

resource "aws_route_table_association" "private_subnet_a_association" {
    subnet_id = "${aws_subnet.private_a.id}"
    route_table_id = "${aws_route_table.private_subnet_rt.id}"
}

resource "aws_route_table_association" "private_subnet_b_association" {
    subnet_id = "${aws_subnet.private_b.id}"
    route_table_id = "${aws_route_table.private_subnet_rt.id}"
}

## SG
resource "aws_security_group" "alb_sg" {
    name = "Q-CTRL-AlbSG"
    vpc_id = "${aws_vpc.vpc.id}"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol =  "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "Q-CTRL-AlbSG"
    }
}

resource "aws_security_group" "web_server_sg" {
    name = "WebServerSG"
    vpc_id = "${aws_vpc.vpc.id}"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = ["${aws_security_group.alb_sg.id}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol =  "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb" "alb" {
    name = "ExternalAlb"
    internal = false
    load_balancer_type = "application"
    security_groups = ["${aws_security_group.alb_sg.id}"]
    subnets = ["${aws_subnet.public_a.id}", "${aws_subnet.public_b.id}"]
}

resource "aws_iam_instance_profile" "web_instance_profile" {
    name = "WebInstanceProfile"
    role = "${aws_iam_role.web_role.name}"
}

resource "aws_iam_role" "web_role" {
    name = "WebInstanceRole"
    path = "/"

    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
    role = "${aws_iam_role.web_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_launch_configuration" "web" {
    name_prefix = "WebServer"
    image_id = "ami-0119aa4d67e59007c"
    instance_type = "t2.micro"
    iam_instance_profile = "${aws_iam_instance_profile.web_instance_profile.name}"
    security_groups = ["${aws_security_group.web_server_sg.id}"]
    user_data = <<EOF
#!/bin/bash
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent
amazon-linux-extras install nginx1.12 -y
echo "<h2 align='center'>My name's Namesh Sanjitha and Q-CTRL should hire me.</h2>" > /usr/share/nginx/html/index.html
systemctl start nginx
systemctl enable nginx
EOF
}

resource "aws_autoscaling_group" "web_asg" {
    name = "${aws_launch_configuration.web.name}"
    max_size = "5"
    min_size = "1"
    desired_capacity = "1"
    vpc_zone_identifier = ["${aws_subnet.private_a.id}", "${aws_subnet.private_b.id}"]
    launch_configuration = "${aws_launch_configuration.web.name}"
    target_group_arns = ["${aws_lb_target_group.web_80.arn}"]
    tag {
        key = "Name"
        value = "WebInstance"
        propagate_at_launch = true
    }
}

resource "aws_lb_target_group" "web_80" {
    name = "WebTG"
    port = 80
    protocol = "HTTP"
    vpc_id = "${aws_vpc.vpc.id}"

    health_check {
        protocol = "HTTP"
        path = "/"
        port = "traffic-port"
        healthy_threshold = 5
        unhealthy_threshold = 2
        timeout = 5
        interval = 30
        matcher = "200"
    }
}

resource "aws_alb_listener" "web_80" {
    load_balancer_arn = "${aws_lb.alb.arn}"
    port = "80"
    protocol = "HTTP"

    default_action {
        type = "forward"
        target_group_arn = "${aws_lb_target_group.web_80.arn}"
    }
}

output "url" {
  value = "${aws_lb.alb.dns_name}"
}
