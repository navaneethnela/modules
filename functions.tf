resource "tls_private_key" "ssh-key" {
  algorithm = "RSA"
  rsa_bits  = 2048

  provisioner "local-exec" {
    command     = <<EOT
    '${tls_private_key.ssh-key.private_key_pem}' | % {$_ -replace "`r", ""} | Set-Content -NoNewline ./'${var.keyname}.pem' -Force
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  provisioner "local-exec" {
    command     = "Remove-Item *.pem -Force"
    interpreter = ["PowerShell", "-Command"]
    when        = destroy
  }
}

resource "aws_key_pair" "generated-key" {
  key_name   = var.keyname
  public_key = tls_private_key.ssh-key.public_key_openssh
}

data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_instance" "instance-1" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  count = 2
  key_name               = aws_key_pair.generated-key.key_name
  user_data_base64       = base64encode(local.mysql_install)
  vpc_security_group_ids = [aws_security_group.EC2_SG.id]
}

resource "aws_security_group" "EC2_SG" {
  name        = "SG_EC2"
  description = "Ec2_SG_Terraform"

  tags = {
    Name = "EC2 Security Group"
  }

  ingress {
    description = "EC2_SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Mysql_Sg"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outside"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
