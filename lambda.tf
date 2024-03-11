variable "aws-region" {
  type        = string  
  description = "Região da AWS"
  default     = "us-east-1"
}

terraform {
  required_version = ">= 1.3, <= 1.7.4"

  required_providers {
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

data "archive_file" "authLambdaArtefact" {
    output_path = "files_lambda/authLambdaArtefact.zip"
    type = "zip"
    source_file = "${path.module}/index.ts"
}

resource "aws_lambda_function" "auth_lambda" {
  function_name = "authLambdaFunction"
  handler = "index.handler"
  role    = aws_iam_role.lambda_execution_role.arn
  runtime = "nodejs18.x"

  filename         = data.archive_file.authLambdaArtefact.output_path
  source_code_hash = filebase64sha256(data.archive_file.authLambdaArtefact.output_path)

  environment {
    variables = {
      COGNITO_USER_POOL_ID = "your-cognito-user-pool-id"
    }
  }
}