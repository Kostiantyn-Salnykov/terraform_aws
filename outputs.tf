output "MyVPCid" {
  description = "Retrieve ID of VPC."
  value       = module.MyVPC.id
}

#output "MyCertificateARN" {
#  description = "MyCertificate ARN."
#  value       = module.MyAWSECS.MyCertificate
#}
