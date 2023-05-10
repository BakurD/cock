
output "elb_dns_name" {
  value = aws_lb.balance.dns_name
}

output "vpc_id" {
  value = aws_vpc.for_bakur.id
}

output "vpc_cidr" {
  value = aws_vpc.for_bakur.cidr_block
}
output "security_group_id" {
  value = aws_security_group.SG.id
}

output "public_subnets_id" {
  value = aws_subnet.public_subnet[*].id
}