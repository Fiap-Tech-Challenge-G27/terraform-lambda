variable "aws-region" {
  type        = string  
  description = "Região da AWS"
  default     = "us-east-1"
}

terraform {
  required_version = ">= 1.3, <= 1.7.5"

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

data "archive_file" "authLambdaArtefact" {
    output_path = "files_lambda/authLambdaArtefact.zip"
    type = "zip"
    source_dir = "${path.module}/lambda"
}

resource "aws_lambda_function" "auth_lambda" {
  function_name = "terraform-lambda"
  handler = "index.handler"
  role    = aws_iam_role.lambda_execution_role.arn
  runtime = "nodejs18.x"

  filename         = data.archive_file.authLambdaArtefact.output_path
  source_code_hash = filebase64sha256(data.archive_file.authLambdaArtefact.output_path)

  layers = [aws_lambda_layer_version.lambdaLayer.arn]

  # environment {
  #   variables = {
  #     POSTGRES_HOST = "your-cognito-user-pool-id"
  #   }
  # }
}

resource "random_string" "jwtSecret" {
  length           = 16
  special          = true
  override_special = "/@\" "
}

resource "aws_secretsmanager_secret" "jwt_credentials" {
  name        = "jwt_credentials"
}

resource "aws_secretsmanager_secret_version" "jwt_credentials_version" {
  secret_id     = aws_secretsmanager_secret.jwt_credentials.id
  secret_string = jsonencode({
    jwtSecret = random_string.jwtSecret.result
  })
}