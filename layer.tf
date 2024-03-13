resource "null_resource" "install_layer_deps" {
    triggers = {
        layer_build = filemd5("${path.module}/layer/package.json")
    }

    provisioner "local-exec" {
        working_dir = "${path.module}/layer"
        command = " npm i &&  npm run build && npm prune --production "
    }
}

data "archive_file" "lambdaLayer" {
    type = "zip"
    output_path = "files_lambda/lambda-layer.zip"
    source_dir = "${path.module}/layer"
    depends_on = [null_resource.install_layer_deps]
}

# resource "aws_s3_object" "object" {
#   bucket = "techchallengestate-g27"
#   key    = "terraform-lambda/lambda"
#   source = data.archive_file.lambdaLayer.output_path

#   etag = filemd5(data.archive_file.lambdaLayer.output_path)

#   depends_on = [ data.archive_file.lambdaLayer ]
# }

resource "aws_lambda_layer_version" "lambdaLayer" {
  layer_name = "lambdaLayer"
  filename = data.archive_file.lambdaLayer.output_path
  source_code_hash = data.archive_file.lambdaLayer.output_base64sha256
  compatible_runtimes = ["nodejs18.x"]

#   depends_on = [ aws_s3_object.object ]
}