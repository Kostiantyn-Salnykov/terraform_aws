IaaC roadmap to create:

- [x] VPC (Internet gateway, subnets, route table, security groups);
- [ ] VPC (NAT Gateway, VPN Endpoint, Elastic IP);
- [x] ~~Domain + Certificates~~ (ACM);
- [x] ECR + Docker (repository, Docker build);
- [x] ECS (cluster, service, task definition);
- [x] SSM (parameters with path);
- [x] SES (domain identity, email identity, register Route53 records);
- [x] SNS (topic);
- [x] CloudWatch (log group, alarm);
- [x] SQS (queue);
- [ ] ElastiCache (cluster, DB, connection via VPN endpoint);
- [x] Lambda Layer (with .zip creation);
- [x] Lambda Function (with layer(s), from source code);
- [x] API Gateway (API, mapping, cognito, lambda, domain);
- [ ] API Gateway (Websocket + lambda | file upload to S3);
- [x] Amplify (Vue.js example app);
- [ ] RDS (PostgreSQL DB, Aurora);
- [x] Cognito (user pool, domain, JWT);
- [x] Cognito oAuth2 (GitHub, Google, etc...);
- [ ] IoT Core (certificates, rule, thing, thing group);
- [ ] S3 with CloudFront (distribute mkdocs-material build, add Basic Auth);
- [ ] DynamoDB;
- [ ] CodeCommit (repository, approval templates, trigger);
- [ ] CodePipeline;
- [ ] CodeBuild;
- [ ] CodeDeploy;

Terraform format
```commandline
terraform fmt -recursive
```

Terraform validate
```commandline
terraform validate
```

Terraform plan
```commandline
terraform plan
```

Run terraform apply with `-var-file` and auto approve.
```commandline
terraform apply -var-file="dev.tfvars" -auto-approve
```
