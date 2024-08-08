resource "null_resource" "install_layer_deps_auth" {
    triggers = {
        always_run = "${timestamp()}"
    }

    provisioner "local-exec" {
        working_dir = "${path.module}/lambda-auth/layer/nodejs"
        command = " npm install --production "
    }
}

resource "null_resource" "install_layer_deps_delete" {
    triggers = {
        always_run = "${timestamp()}"
    }

    provisioner "local-exec" {
        working_dir = "${path.module}/lambda-delete/layer/nodejs"
        command = " npm install --production "
    }
}

data "archive_file" "lambdaLayerAuth" {
    type = "zip"
    output_path = "files_lambda/lambda-layer-auth.zip"
    source_dir = "${path.module}/lambda-auth/layer/nodejs"
    depends_on = [null_resource.install_layer_deps_auth]
}

data "archive_file" "lambdaLayerDelete" {
    type = "zip"
    output_path = "files_lambda/lambda-layer-delete.zip"
    source_dir = "${path.module}/lambda-delete/layer/nodejs"
    depends_on = [null_resource.install_layer_deps_delete]
}

resource "aws_lambda_layer_version" "lambdaLayerAuth" {
  layer_name = "lambdaAuth"
  filename = data.archive_file.lambdaLayerAuth.output_path
  source_code_hash = data.archive_file.lambdaLayerAuth.output_base64sha256
  compatible_runtimes = ["nodejs18.x"]
}

resource "aws_lambda_layer_version" "lambdaLayerDelete" {
  layer_name = "lambdaDelete"
  filename = data.archive_file.lambdaLayerDelete.output_path
  source_code_hash = data.archive_file.lambdaLayerDelete.output_base64sha256
  compatible_runtimes = ["nodejs18.x"]
}