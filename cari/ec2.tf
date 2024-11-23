# EC2 인스턴스 프로필
resource "aws_iam_instance_profile" "cari" {
  name = "request-${terraform.workspace}.cari.profile"
  role = aws_iam_role.cari.name
}

# EC2 인스턴스 보안 그룹
resource "aws_security_group" "cari" {
  name   = "request-${terraform.workspace}.cari.sg"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 인스턴스
resource "aws_instance" "cari" {

  ami                    = "ami-06f73fc34ddfd65c2" # Amazon Linux 2023 AMI
  instance_type          = "t2.micro"
  subnet_id              = data.terraform_remote_state.network.outputs.private_subnet_id
  vpc_security_group_ids = [aws_security_group.cari.id]
  iam_instance_profile   = aws_iam_instance_profile.cari.name

  user_data = <<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    yum update -y
    yum install -y docker
    service docker start
    usermod -a -G docker ec2-user

    # Docker Compose 설치
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # CodeDeploy 에이전트 설치
    yum install -y ruby wget
    cd /home/ec2-user
    wget https://aws-codedeploy-${var.aws_region}.s3.${var.aws_region}.amazonaws.com/latest/install
    chmod +x ./install
    ./install auto

    # 환경 변수 주입
    sudo touch /etc/profile.d/env.sh
    sudo echo "#!/bin/bash" >> /etc/profile.d/env.sh
    source /etc/profile
  EOF
  tags = {
    Name = "request-${terraform.workspace}.cari"
  }
}

# VPC Endpoint
resource "aws_vpc_endpoint" "codedeploy" {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  service_name = "com.amazonaws.ap-northeast-2.codedeploy"
  vpc_endpoint_type = "Interface"
  security_group_ids = [
    aws_security_group.cari.id,
  ]

  private_dns_enabled = true
}

# VPC Endpoint Secure
resource "aws_vpc_endpoint" "codedeploy-commands-secure" {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  service_name = "com.amazonaws.ap-northeast-2.codedeploy-commands-secure"
  vpc_endpoint_type = "Interface"
  security_group_ids = [
    aws_security_group.cari.id,
  ]

  private_dns_enabled = true
}
