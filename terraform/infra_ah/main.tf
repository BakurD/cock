#VPC and it config
resource "aws_vpc" "for_bakur" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = var.vpc_tags
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.for_bakur.id
  tags = {
    "Name" = "Bakurs IGW"
  }
}
# Security group
resource "aws_security_group" "SG" {
  vpc_id = aws_vpc.for_bakur.id
  name = "HTTP-HTTPS-SSH"
  dynamic "ingress" {
    for_each = ["80", "443", "22", "8080"]
    content {
      from_port = ingress.value
      to_port = ingress.value
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress  {
    cidr_blocks = [ "0.0.0.0/0" ]
    from_port = 0
    protocol = "-1"
    to_port = 0
  }
}
#Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.for_bakur.id
  count = length(var.public_subnet_cidr)
  cidr_block = element(var.public_subnet_cidr, count.index)
  availability_zone = data.aws_availability_zones.availability.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    "Name" = "Publuc Subnet"
  }
}

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.for_bakur.id
  route  {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  tags = {
    "Name" = "Route table for public subnet"
  }
}

resource "aws_route_table_association" "public_associate" {
  count = length(aws_subnet.public_subnet[*].id)
  subnet_id = element(aws_subnet.public_subnet[*].id, count.index)
  route_table_id = aws_route_table.public_route.id
}
#Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.for_bakur.id
  cidr_block = var.private_subnet
  availability_zone = data.aws_availability_zones.availability.names[0]
  map_public_ip_on_launch = false
  tags = {
    "Name" = "Private Subnet"
  }
}

resource "aws_route_table" "private_route" {
  vpc_id = aws_vpc.for_bakur.id
  tags = {
    "Name" = "Route table for private subnet"
  }
}

resource "aws_route_table_association" "private_associatin" {
  count = length(aws_subnet.public_subnet[*].id)
  subnet_id = element(aws_subnet.private_subnet[*].id, count.index)
  route_table_id = aws_route_table.private_route.id
}

resource "aws_eip" "NAT" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.NAT.id
  subnet_id = aws_subnet.public_subnet[0].id
  tags = {
    "Name"  = "NAT"
  }
}

resource "aws_route" "private_route_nat" {
  route_table_id = aws_route_table.private_route.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id
}

resource "aws_route" "public_route_nat" {
  route_table_id = aws_route_table.public_route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.IGW.id
}

#Create LB, LC, ASG permanently delete

resource "aws_launch_configuration" "LC" {
    name_prefix = "Hight Availability"
    associate_public_ip_address = true
    key_name = "CI_CD"
    image_id = data.aws_ami.latest_ubuntu.id
    instance_type = "t2.micro"
    security_groups = [aws_security_group.SG.id]
    user_data = <<EOF
#!/bin/bash
sudo apt update -y
sudo apt install apache2 -y
echo "<html><body bgcolor=white><center><h2><p><front color=red>Bootstraping one love</h2></center></html>" > /var/www/html/index.html
sudo service apache2 start
chkconfig apache2 on
echo "UserData excuted on $(date)" >> /var/www/html/log.txt
EOF
    lifecycle {
      create_before_destroy = true
    }
    
}

resource "aws_autoscaling_group" "web" {
  name = "ASG-${aws_launch_configuration.LC.name}"
  launch_configuration = aws_launch_configuration.LC.name
  min_size = var.min_size
  max_size = var.max_size
  min_elb_capacity = var.min_elb
  vpc_zone_identifier = [element(aws_subnet.public_subnet.*.id, 1), element(aws_subnet.public_subnet.*.id, 0)]
  health_check_type = "ELB"
  health_check_grace_period = 300
  target_group_arns = ["${aws_lb_target_group.target_balancer.arn}"]
  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG"
      Owner  = "Maxim Bakurevych"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_launch_configuration.LC
  ]
}

resource "aws_lb_target_group" "target_balancer" {
  name_prefix = "tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.for_bakur.id
}

resource "aws_lb_listener" "listener_balancer" {
  load_balancer_arn = "${aws_lb.balance.arn}"
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = "${aws_lb_target_group.target_balancer.arn}"
  }
}

resource "aws_lb" "balance" {
  name = "elb"
  internal = false
  security_groups = [aws_security_group.SG.id]
  subnets = [element(aws_subnet.public_subnet.*.id, 1), element(aws_subnet.public_subnet.*.id, 0)]
}

