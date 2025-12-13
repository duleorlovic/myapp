# We define following resources:
# VPC_PART
# ELASTICACHE_PART
# LOAD_BALANCER_PART
# IAM_PART and S3_PART
# RDS_PART
# INSTANCE_PART

### START OF VPC_PART
# You can use module https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
# Or specify each resource separately
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "myapp-vpc" {
  # define 10.0.x.x vpc
  cidr_block           = "10.0.0.0/16"
  # enable dns hostnames
  enable_dns_hostnames = "true"

  tags = {
    Name = "myapp-vpc"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
resource "aws_subnet" "myapp-subnet-public" {
  vpc_id                  = aws_vpc.myapp-vpc.id
  # define 10.0.1.x subnet
  cidr_block              = "10.0.1.0/24"
  # this will actually differentiate public and private subnets
  map_public_ip_on_launch = "true"
  # aws ec2 describe-availability-zones eu-central-1a
  availability_zone       = "${var.terraform_aws_region}a"

  tags = {
    Name = "myapp-subnet-public"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
resource "aws_subnet" "myapp-subnet-private" {
  vpc_id                  = aws_vpc.myapp-vpc.id
  # define 10.0.1.x subnet
  cidr_block              = "10.0.2.0/24"
  # this will actually differentiate public and private subnets
  map_public_ip_on_launch = "false"
  # aws ec2 describe-availability-zones eu-central-1a
  availability_zone       = "${var.terraform_aws_region}b"

  tags = {
    Name = "myapp-subnet-private"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "myapp-internet-gateway" {
  vpc_id = aws_vpc.myapp-vpc.id

  tags = {
    Name = "myapp-internet-gateway"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "myapp-route-table-public" {
  vpc_id = aws_vpc.myapp-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-internet-gateway.id
  }

  tags = {
    Name = "myapp-route-table-public"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
# this will actually differentiate public and private subnets
resource "aws_route_table_association" "myapp-route-table-association--public" {
  subnet_id      = aws_subnet.myapp-subnet-public.id
  route_table_id = aws_route_table.myapp-route-table-public.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "myapp-security-group-allow-ssh" {
  vpc_id      = aws_vpc.myapp-vpc.id
  # this is a security group name that is usually shown along with id
  name        = "myapp-security-group-allow-ssh"
  description = "security group that allows ssh traffic"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # this is a tag that is usually shown on index page, case sensitive
  tags = {
    Name = "myapp-security-group-allow-ssh"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "myapp-security-group-allow-egress" {
  vpc_id      = aws_vpc.myapp-vpc.id
  # this is a security group name that is usually shown along with id
  name        = "myapp-security-group-allow-egress"
  description = "security group that allows all egress traffic"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # this is a tag that is usually shown on index page, case sensitive
  tags = {
    Name = "myapp-security-group-allow-egress"
  }
}

# I use this so I can ping any instances in my VPC
resource "aws_security_group" "myapp-security-group-allow-ping" {
  vpc_id      = aws_vpc.myapp-vpc.id
  name        = "myapp-security-group-allow-ping"
  description = "security group that allows ping to it"
  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "myapp-security-group-allow-ping"
  }
}
### END OF VPC_PART

### START OF ELASTICACHE_PART
resource "aws_security_group" "myapp-security-group-allow-redis" {
  vpc_id      = aws_vpc.myapp-vpc.id
  name        = "myapp-security-group-allow-redis"
  description = "security group that allows 6379 from our network"
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [ aws_security_group.myapp-security-group-allow-ssh.id ]
  }
  tags = {
    Name = "myapp-security-group-allow-redis"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_cluster
resource "aws_elasticache_subnet_group" "myapp-elasticache-subnet-group" {
  name       = "myapp-elasticache-subnet-group"
  subnet_ids = [
    aws_subnet.myapp-subnet-public.id,
    aws_subnet.myapp-subnet-private.id,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_parameter_group
resource "aws_elasticache_parameter_group" "myapp-elasticache-parameter-group-sidekiq-redis" {
  name        = "myapp-elasticache-parameter-group-sidekiq-redis"
  family      = "redis7" # or redis6.x, redis7 depending on your Redis version

  parameter {
    name  = "maxmemory-policy"
    # https://github.com/mperham/sidekiq/wiki/Using-Redis#memory maxmemory-policy noeviction
    value = "noeviction"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_cluster
resource "aws_elasticache_cluster" "myapp-elasticache-cluster-redis" {
  cluster_id           = "myapp-elasticache-cluster-redis"
  engine               = "redis"
  node_type            = var.instance_redis_type
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.myapp-elasticache-parameter-group-sidekiq-redis.name
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.myapp-elasticache-subnet-group.name
  security_group_ids   = [aws_security_group.myapp-security-group-allow-redis.id]
  tags = {
    Name = "myapp-elasticache-cluster-redis"
  }
}
output "myapp-redis-enpoint-url" {
  description = "The address of the Redis single node cluster"
  value = aws_elasticache_cluster.myapp-elasticache-cluster-redis.cache_nodes[0].address
}
### END OF ELASTICACHE_PART


# ### START OF LOAD_BALANCER_PART
resource "aws_security_group" "myapp-security-group-allow-80" {
  vpc_id      = aws_vpc.myapp-vpc.id
  name        = "myapp-security-group-allow-80"
  description = "security group that allows 80"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "myapp-security-group-allow-80"
  }
}

resource "aws_security_group" "myapp-security-group-allow-443" {
  vpc_id      = aws_vpc.myapp-vpc.id
  name        = "myapp-security-group-allow-443"
  description = "security group that allows 443"
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "myapp-security-group-allow-443"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb#network-load-balancer
resource "aws_lb" "myapp-alb" {
  name               = "myapp-alb"
  load_balancer_type = "application"
  subnets            = [
    aws_subnet.myapp-subnet-public.id,
    aws_subnet.myapp-subnet-private.id,
  ]
  security_groups = [
    aws_security_group.myapp-security-group-allow-80.id,
    aws_security_group.myapp-security-group-allow-443.id,
    aws_security_group.myapp-security-group-allow-egress.id,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
resource "aws_lb_target_group" "myapp-lb-target-group" {
  name     = "myapp-lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myapp-vpc.id
  # We should specifify health_check since default is root / and if you have 
  # redirection eg redirect to mydomain.com than it will fail, better is to use
  # config/routes.rb
  #   get "/up", to: proc { [200, {}, ["OK"]] }
  health_check {
    path                = "/up"
    interval            = 30
    protocol            = "HTTP"
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "myapp-http-listener" {
  load_balancer_arn = aws_lb.myapp-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myapp-lb-target-group.arn
  }
}

# Launch Template for Auto Scaling Group is initially default ami but after cap deploy ami is changed
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
# this is used instead of resource "aws_instance" "myapp-instance-app" {
resource "aws_launch_template" "myapp-launch-template" {
  name_prefix   = "myapp-launch-template"
  image_id      = var.amis[var.terraform_aws_region]
  # t2.micro automatically adds 8GB EBS storage Elastic block storage
  instance_type = var.instance_type

  network_interfaces {
    # the VPC subnet, if not defined, default VPC is used, note that security
    # group needs to be in the same vpc as instance
    subnet_id = aws_subnet.myapp-subnet-public.id
    associate_public_ip_address = true
    security_groups = [
      aws_security_group.myapp-security-group-allow-ssh.id,
      aws_security_group.myapp-security-group-allow-egress.id,
      aws_security_group.myapp-security-group-allow-ping.id,
      aws_security_group.myapp-security-group-allow-80.id,
    ]
  }

  # the public SSH key
  key_name = aws_key_pair.myapp-key-pair.key_name

  block_device_mappings {
    device_name = "/dev/sda1"  # Specify the device name
    ebs {
      # default 8GB is not enough so use larger disk size
      volume_size = 20
    }
  }

  user_data = base64encode(local.cloud_init_script_for_app)

  depends_on = [aws_db_instance.myapp-db-instance]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "myapp-launch-template"
    }
  }

  # on each be cap staging deploy, image_id and latest_version are changed
  # we do not need to ignore latest_version since it is decided by the provider
  lifecycle {
    ignore_changes = [
      image_id,
    ]
  }
}

# Any change in the launch template version should force recreation
resource "terraform_data" "asg_instance_refresh" {
  triggers_replace = {
    launch_template_version = aws_launch_template.myapp-launch-template.latest_version
  }

  provisioner "local-exec" {
    command = <<EOF
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name ${aws_autoscaling_group.myapp-autoscaling-group.name}
EOF
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
resource "aws_autoscaling_group" "myapp-autoscaling-group" {
  launch_template {
    id      = aws_launch_template.myapp-launch-template.id
    version = "$Latest"
  }
  name                 = "myapp-autoscaling-group"
  desired_capacity     = 1
  max_size             = 1 # TODO: after first deploy change from 1 to 5
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.myapp-subnet-public.id]

  target_group_arns = [aws_lb_target_group.myapp-lb-target-group.arn]

  health_check_type      = "EC2" # TODO: after first deploy change from EC2 to ELB

  tag {
    key                 = "Name"
    value               = "myapp-autoscaling-group"
    propagate_at_launch = true
  }
}

output "ssh_commands_app" {
  value = <<-HERE_DOC
    ssh-add ${replace(var.path_to_public_key, ".pub", "")}
    # Instance might not be created (autoscaling_group will create it)
    ssh ubuntu@${aws_lb.myapp-alb.dns_name}
    # You can use capistrano to ssh to first instance
    bundle exec cap staging ssh
  HERE_DOC
}
# ### END OF LOAD_BALANCER_PART

# #### START OF IAM_PART S3_PART
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
resource "aws_s3_bucket" "myapp-s3-bucket" {
  bucket = "myapp-s3-bucket"
  force_destroy = true # this will remove all files when destroying the bucket

  tags = {
    Name        = "myapp-s3-bucket"
  }
}
# IAM User for Elbas and S3
resource "aws_iam_user" "myapp-iam-user-elbas" {
  name = "myapp-iam-user-elbas"
}

resource "aws_iam_access_key" "myapp-iam-access-key-elbas" {
  user = aws_iam_user.myapp-iam-user-elbas.name
}

resource "aws_iam_user_policy_attachment" "myapp-iam-user-policy-attachment-ec2-full-access" {
  user       = aws_iam_user.myapp-iam-user-elbas.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_user_policy" "myapp-iam-user-s3-policy" {
  name = "myapp-iam-user-s3-policy"
  user = aws_iam_user.myapp-iam-user-elbas.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"  # optional if you want to allow setting ACLs (e.g., public-read)
        ],
        Resource = "arn:aws:s3:::${aws_s3_bucket.myapp-s3-bucket.id}/*"
      }
    ]
  })
}

output "aws_elbas_access_key_id" {
  value = aws_iam_access_key.myapp-iam-access-key-elbas.id
}

# to see the value run: terraform output
output "aws_elbas_secret_access_key" {
  value = aws_iam_access_key.myapp-iam-access-key-elbas.secret
  sensitive = true
}
### END OF IAM_PART

### START OF RDS_PART
resource "aws_security_group" "myapp-security-group-rds" {
  name   = "myapp-security-group-rds"
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [ aws_security_group.myapp-security-group-allow-ssh.id ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "myapp-security-group-rds"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group
resource "aws_db_subnet_group" "myapp-db-subnet-group" {
  name       = "main"
  subnet_ids = [
    aws_subnet.myapp-subnet-public.id,
    aws_subnet.myapp-subnet-private.id
  ]

  tags = {
    Name = "myapp-db-subnet-group"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance
resource "random_password" "db_password" {
  length  = 16
  special = false
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance
resource "aws_db_instance" "myapp-db-instance" {
  allocated_storage    = 10
  db_name              = "myappdbinstance"
  db_subnet_group_name = aws_db_subnet_group.myapp-db-subnet-group.name
  engine               = "postgres"
  engine_version       = "15.12"
  instance_class       = var.instance_db_type
  username             = "dbuser"
  password             = random_password.db_password.result
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.myapp-security-group-rds.id]

  tags = {
    Name = "myapp-db-instance"
  }
}

output "db_instance_endpoint" {
  description = "The connection endpoint"
  value = aws_db_instance.myapp-db-instance.endpoint
}
### END OF RDS_PART

resource "random_password" "secret_key_base" {
  length  = 128
  special = true
}

### START OF INSTANCE_PART
locals {
  install_ruby = templatefile("${path.module}/templates/install_ruby.sh.tpl", {
    elasticache-cluster-redis-address = aws_elasticache_cluster.myapp-elasticache-cluster-redis.cache_nodes[0].address
    ruby_version = var.ruby_version
    bundler_version = var.bundler_version
    node_version = var.node_version
  })
  install_sidekiq = templatefile("${path.module}/templates/install_sidekiq.sh.tpl", {})
  rbenv_vars = templatefile("${path.module}/templates/rbenv.vars.tpl", {
    rails_env = var.rails_env
    database_url = "postgresql://${aws_db_instance.myapp-db-instance.username}:${random_password.db_password.result}@${aws_db_instance.myapp-db-instance.endpoint}/${aws_db_instance.myapp-db-instance.db_name}"
    redis_url = "redis://${aws_elasticache_cluster.myapp-elasticache-cluster-redis.cache_nodes[0].address}:6379/1"
    secret_key_base = random_password.secret_key_base.result
    aws_region = var.terraform_aws_region
    aws_bucket = aws_s3_bucket.myapp-s3-bucket.id
    aws_access_key_id = aws_iam_access_key.myapp-iam-access-key-elbas.id
    aws_secret_access_key = aws_iam_access_key.myapp-iam-access-key-elbas.secret
    rails_master_key = var.rails_master_key
  })

  cloud_init_script_for_worker = <<-HERE_DOC
    #cloud-config
    package_update: true
    # do not recreate ssh keys from root and ubuntu .ssh/authorized_keys so we do not need to ssh-keygen -R
    ssh_deletekeys: false
    hostname: ${var.rails_env}-worker
    packages:
      - vim-nox
      # Database is on Amazon RDS so we just need to install the client
      - postgresql
      - postgresql-contrib
      - libpq-dev
      - jq
      - multitail

    runcmd:
    ${local.install_ruby}
    ${local.install_sidekiq}
    write_files:
      # since write_files parent folders will be owned by root (eg /home/ubuntu
      # folder) we will copy those files in runcmd and change owner
      - path: /root/prepare_files_for_ubuntu_user/.rbenv-vars
        content: |
          ${indent(6, local.rbenv_vars)}
        permissions: "0644"
      - path: /root/.bash_aliases
        content: |
          ${indent(6, file("templates/bash_aliases.sh"))}
      - path: /root/prepare_files_for_ubuntu_user/.config/systemd/user/sidekiq.service
        content: |
          ${indent(6, file("../config/etc/systemd/system/sidekiq.service"))}
        permissions: "0644"
  HERE_DOC

  cloud_init_script_for_app = <<-HERE_DOC
    #cloud-config
    package_update: true
    # do not recreate ssh keys from root and ubuntu .ssh/authorized_keys so we do not need to ssh-keygen -R
    ssh_deletekeys: false
    hostname: ${var.rails_env}-app
    packages:
      - vim-nox
      # Database is on Amazon RDS so we just need to install the client
      - postgresql
      - postgresql-contrib
      - libpq-dev
      - nginx
      - multitail

    runcmd:
    ${local.install_ruby}
    - echo "startApp `date`" >> /root/cloud_init_script.log
    - cp /root/prepare_files_for_ubuntu_user/puma.service /etc/systemd/system
    - systemctl daemon-reload
    - systemctl enable puma.service
    - rm -rf /etc/nginx/sites-enabled/default
    - cp /root/prepare_files_for_ubuntu_user/nginx_puma /etc/nginx/sites-enabled
    # we need to add www-data to ubuntu user since nginx need access to ubuntu files
    - usermod -aG ubuntu www-data
    - systemctl reload nginx
    - echo "endApp `date`" >> /root/cloud_init_script.log
    write_files:
      # since write_files parent folders will be owned by root (eg /home/ubuntu
      # folder) we will copy those files in runcmd and change owner
      - path: /root/prepare_files_for_ubuntu_user/.rbenv-vars
        content: |
          ${indent(6, local.rbenv_vars)}
        permissions: "0644"
      - path: /root/.bash_aliases
        content: |
          ${indent(6, file("templates/bash_aliases.sh"))}
      - path: /root/prepare_files_for_ubuntu_user/puma.service
        content: |
          ${indent(6, file("../config/etc/systemd/system/puma.service"))}
        permissions: "0644"
      - path: /root/prepare_files_for_ubuntu_user/nginx_puma
        content: |
          ${indent(6, file("../config/etc/nginx/sites-enabled/nginx_puma"))}
        permissions: "0644"
  HERE_DOC
}

# Key is generated with
# ssh-keygen -f myapp_key
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair
resource "aws_key_pair" "myapp-key-pair" {
  # existing keys can be imported with: terraform import aws_key_pair.deployer deployer-key
  # https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#KeyPairs:
  # myapp-key-pair will be destroyed when we run terraform destroy
  # Find IP address from aws console or using output and test connection with
  # ssh -i myapp_key ubuntu@3.84.117.126
  key_name = "myapp-key-pair"
  public_key = file(var.path_to_public_key)
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
resource "aws_instance" "myapp-instance-worker" {
  ami           = var.amis[var.terraform_aws_region]
  # t2.micro automatically adds 8GB EBS storage Elastic block storage
  instance_type = var.instance_type

  # the VPC subnet, if not defined, default VPC is used, note that security
  # group needs to be in the same vpc as instance
  subnet_id = aws_subnet.myapp-subnet-public.id

  # the security group, if not defined, default security group is used
  vpc_security_group_ids = [
    aws_security_group.myapp-security-group-allow-ssh.id,
    aws_security_group.myapp-security-group-allow-egress.id,
    aws_security_group.myapp-security-group-allow-ping.id,
  ]

  # the public SSH key
  key_name = aws_key_pair.myapp-key-pair.key_name

  root_block_device {
    # default 8GB is not enough so use larger disk size
    volume_size = 20
  }

  # you can check the content with:
  # ssh ubuntu@worker.myapp.com sudo cat /var/lib/cloud/instance/user-data.txt
  user_data = local.cloud_init_script_for_worker

  depends_on = [aws_db_instance.myapp-db-instance]

  tags = {
    Name = "myapp-instance-worker"
  }
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip#single-eip-associated-with-an-instance
resource "aws_eip" "myapp-eip-worker" {
  instance = aws_instance.myapp-instance-worker.id

  tags = {
    Name = "myapp-eip-worker"
  }
}

output "ssh_commands_worker" {
  value = <<-HERE_DOC
    ssh-add ${replace(var.path_to_public_key, ".pub", "")}
    # ssh to worker instance with elastic ip address
    ssh ubuntu@${aws_eip.myapp-eip-worker.public_ip}
    # which should be mapped with staging-worker on main route53
    ssh ubuntu@staging-worker.myapp.com
  HERE_DOC
}
### END OF INSTANCE_PART
