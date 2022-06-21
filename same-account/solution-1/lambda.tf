# Create Lambda Function to Generate Test Logs and Transform Data from Firehose

# Create CloudWatch Log Group for Log Generator Lambda Function
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name = "/aws/lambda/${aws_lambda_function.log_generator.function_name}"
}

# Create IAM role and policy to allow CloudWatch Logs to write to Firehose
resource "aws_iam_role" "cwl_firehose" {
  name               = "CWL_Firehose_Role_Solution_1"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "logs.ap-southeast-1.amazonaws.com"},
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringLike": {
          "aws:SourceArn": "arn:aws:logs:ap-southeast-1:${var.log_sender_ID}:*"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy" "cwl_firehose" {
  name   = "CWL_Firehose_Policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["firehose:*"],
      "Resource": ["arn:aws:firehose:ap-southeast-1:${var.log_sender_ID}:*"]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cwl_firehose_policy" {
  role       = aws_iam_role.cwl_firehose.name
  policy_arn = aws_iam_policy.cwl_firehose.arn
}

# Create subscription filter to Firehose
resource "aws_cloudwatch_log_subscription_filter" "lambda_logs" {
  name            = "same-account-solution-1"
  role_arn        = aws_iam_role.cwl_firehose.arn
  log_group_name  = aws_cloudwatch_log_group.lambda_logs.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.test_stream.arn
}

# Create IAM role and policy for Log Generator Lambda function
resource "aws_iam_role" "log_generator_lambda_role" {
  name               = "Log_Generator_Lambda_Role_Solution_1"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "log_generator_lambda_policy" {
  name        = "Log_Generator_Lambda_Policy"
  path        = "/"
  description = "IAM policy for logging from a Lambda"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "log_generator_policy" {
  role       = aws_iam_role.log_generator_lambda_role.name
  policy_arn = aws_iam_policy.log_generator_lambda_policy.arn
}

# Create a zip file of the python code
data "archive_file" "log_zip_code" {
  type        = "zip"
  source_dir  = "${path.module}/log-generator/"
  output_path = "${path.module}/log-generator/log-generator.zip"
}

# Create the lambda function
resource "aws_lambda_function" "log_generator" {
  filename      = "${path.module}/log-generator/log-generator.zip"
  function_name = "Log-Generator-Solution-1"
  role          = aws_iam_role.log_generator_lambda_role.arn
  handler       = "log_generator.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.log_generator_policy]
  timeout       = 300
  description   = "Lambda function to generate test logs"
  tags          = var.tags
}

# Create Lambda Function for Data Transformation

# Create IAM roles and Policies for the Data Transformation Lambda function
resource "aws_iam_role" "data_transform_lambda_role" {
  name               = "Data_Transformation_Lambda_Role"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow"
    }
 ]
}
EOF
}

resource "aws_iam_policy" "data_transform_lambda_policy" {

  name        = "Data_Transformation_Lambda_Policy"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "data_transform_policy" {
  role       = aws_iam_role.data_transform_lambda_role.name
  policy_arn = aws_iam_policy.data_transform_lambda_policy.arn
}

# Create a zip file of the python code
data "archive_file" "python_zip_code" {
  type        = "zip"
  source_dir  = "${path.module}/transform/"
  output_path = "${path.module}/transform/cwl_transform.zip"
}

# Create the lambda function
resource "aws_lambda_function" "data_transform" {
  filename      = "${path.module}/transform/cwl_transform.zip"
  function_name = "Data-Transformation-Lambda-Function"
  role          = aws_iam_role.data_transform_lambda_role.arn
  handler       = "cwl_transform.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.data_transform_policy]
  timeout       = 300
  description   = "Lambda function to transform data coming from CW Logs"
  tags          = var.tags
}