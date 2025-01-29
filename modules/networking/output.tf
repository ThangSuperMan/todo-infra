output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "trusted_subnet_ids" {
  value = aws_subnet.trusted_subnet[*].id

}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet[*].id
}
