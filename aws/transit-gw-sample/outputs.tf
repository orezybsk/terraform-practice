output "ec2-a-publc-dns" {
  value = aws_instance.ec2-a.public_dns
}
output "ec2-b-private-dns" {
  value = aws_instance.ec2-b.private_dns
}
output "ec2-a-id" {
  value = aws_instance.ec2-a.id
}
output "ec2-b-id" {
  value = aws_instance.ec2-b.id
}
