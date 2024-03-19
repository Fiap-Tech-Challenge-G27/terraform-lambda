resource "null_resource" "install_layer_deps" {
    triggers = {
        always_run = "${timestamp()}"
    }

    provisioner "local-exec" {
        working_dir = "${path.module}/layer/nodejs"
        command = " npm install --production "
    }
}

data "archive_file" "lambdaLayer" {
    type = "zip"
    output_path = "files_lambda/lambda-layer.zip"
    source_dir = "${path.module}/layer"
    depends_on = [null_resource.install_layer_deps]
}

resource "aws_lambda_layer_version" "lambdaLayerTech" {
  layer_name = "lambdaAuthTech"
  filename = data.archive_file.lambdaLayer.output_path
  source_code_hash = data.archive_file.lambdaLayer.output_base64sha256
  compatible_runtimes = ["nodejs18.x"]
}