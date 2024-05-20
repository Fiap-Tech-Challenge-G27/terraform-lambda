variable "aws-region" {
  type        = string  
  description = "Região da AWS"
  default     = "us-east-1"
}

terraform {
  required_version = ">= 1.8"

  backend "s3" {
    bucket         = "techchallengestate-g27"
    key            = "terraform-lambda/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }

  required_providers {
    
    random = {
      version = "~> 3.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.65"
    }
  }
}

provider "aws" {
  region = var.aws-region
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_secret" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "archive_file" "authLambdaArtefact" {
    output_path = "files_lambda/authLambdaArtefact.zip"
    type = "zip"
    source_file = "${path.module}/lambda/index.js"
}

resource "aws_default_vpc" "vpcTechChallenge" {
  tags = {
    Name = "Default VPC to Tech Challenge"
  }
}

resource "aws_default_subnet" "subnetTechChallenge" {
  availability_zone = "us-east-1a"

  tags = {
    Name = "Default subnet for us-east-1a to Tech Challenge",
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_default_subnet" "subnetTechChallenge2" {
  availability_zone = "us-east-1b"

  tags = {
    Name = "Default subnet for us-east-1b to Tech Challenge",
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_security_group" "allow_all_egress" {
  name        = "allow-all-ingress"
  description = "Allow all ingress traffic"
  vpc_id      = aws_default_vpc.vpcTechChallenge.id  # Substitua var.vpc_id pelo ID da sua VPC

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitindo tráfego para qualquer destino
  }

}

resource "aws_lambda_function" "auth_lambda" {
  function_name = "terraform-lambda"
  handler = "index.handler"
  role    = aws_iam_role.lambda_execution_role.arn
  runtime = "nodejs18.x"

  filename         = data.archive_file.authLambdaArtefact.output_path
  source_code_hash = filebase64sha256(data.archive_file.authLambdaArtefact.output_path)

  layers = [aws_lambda_layer_version.lambdaLayerTech.arn]

  vpc_config {
    subnet_ids         = [aws_default_subnet.subnetTechChallenge.id, aws_default_subnet.subnetTechChallenge2.id]
    security_group_ids = [aws_security_group.allow_all_egress.id] # Se necessário, substitua lambda_sg pelo ID do seu Security Group
  }

}

output "lambda_function_name" {
  value = aws_lambda_function.auth_lambda.function_name
}

output "lambda_function_invoke_arn" {
  value = aws_lambda_function.auth_lambda.invoke_arn
}

resource "aws_secretsmanager_secret" "jwt_credentials" {
  name        = "jwt_credentials"
}

resource "aws_secretsmanager_secret_version" "jwt_credentials_version" {
  secret_id     = aws_secretsmanager_secret.jwt_credentials.id
  secret_string = jsonencode({
    jwtSecret = "secret"
  })
}