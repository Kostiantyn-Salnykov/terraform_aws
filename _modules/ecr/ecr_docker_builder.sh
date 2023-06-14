# Use sudo rm ~/.docker/config.json
aws ecr get-login-password --region ${aws_region} | docker login -u AWS --password-stdin ${account_id}.dkr.ecr.${aws_region}.amazonaws.com
docker build -t "${repository_url}:latest" -f ${dockerfile_path} .
docker push "${repository_url}:latest"
