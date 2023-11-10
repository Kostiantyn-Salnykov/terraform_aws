IaaC roadmap to create:

- [x] VPC (Internet gateway, subnets, route table, security groups);
- [x] ~~Domain + Certificates~~ (ACM);
- [x] ECR + Docker (repository, Docker build) - FastAPI image;
- [x] ECS (cluster, service, task definition) - FastAPI service;
- [x] SSM (parameters with path);
- [x] SES (domain identity, email identity, register Route53 records);
- [x] SNS (topic);
- [x] CloudWatch (log group, alarm);
- [x] SQS (queue);
- [x] Lambda Layer (with .zip creation);
- [x] Lambda Function (with layer(s), from source code);
- [x] API Gateway (API, mapping, cognito, lambda, domain);
- [x] API Gateway (Websocket + lambda);
- [x] Amplify (Vue.js example app);
- [x] Cognito (user pool, domain, JWT authorizer);
- [x] Cognito oAuth2 (GitHub, Google, etc...);
- [x] RDS (PostgreSQL); 
- [ ] RDS (Aurora);
- [ ] ElastiCache (cluster, DB, connection via VPN endpoint);
- [ ] API Gateway (file upload to S3);
- [x] API Gateway (Websocket `$connect`/`$disconnect`/`$default` + Request Authorizer);
- [ ] IoT Core (certificates, rule, thing, thing group);
- [x] S3 with CloudFront (distribute mkdocs-material build, add Basic Auth);
- [ ] VPC (NAT Gateway, VPN Endpoint, Elastic IP);
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
terraform apply -var-file=".dev.tfvars" -auto-approve
```
