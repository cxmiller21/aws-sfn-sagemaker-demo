data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#################################################
# ECR Repository
#################################################
resource "aws_ecr_repository" "ecr_repository" {
  name                 = local.project_prefix
  image_tag_mutability = "MUTABLE"

  # Delete the repository even if it contains images
  force_delete = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

#################################################
# S3 Buckets
#################################################
module "training_data_bucket" {
  source        = "github.com/cxmiller21/terraform-modules//modules/aws/s3"
  bucket_name   = local.s3_training_data_bucket_name
  force_destroy = true
}

resource "aws_s3_object" "training_data" {
  bucket = module.training_data_bucket.bucket_name
  key    = "iris.csv"
  source = local.s3_object_training_data
}

module "model_output_bucket" {
  source        = "github.com/cxmiller21/terraform-modules//modules/aws/s3"
  bucket_name   = local.s3_output_models_bucket_name
  force_destroy = true
}

#################################################
# Step Function
#################################################
resource "aws_cloudwatch_log_group" "sfn" {
  name              = "/aws/vendedlogs/states/${local.project_prefix}-state-machine"
  retention_in_days = 3
}

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "${local.project_prefix}-state-machine"
  role_arn = aws_iam_role.sf_exec_role.arn

  definition = <<-EOF
  {
  "Comment": "An AWS Step Function State Machine to train, build and deploy an Amazon SageMaker model endpoint",
  "StartAt": "Configuration Lambda",
  "States": {
    "Configuration Lambda": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda_function.arn}",
      "Parameters": {
        "PrefixName": "${local.project_prefix}",
        "input_training_path": "$.input_training_path"
      },
      "Next": "Create Training Job",
      "ResultPath": "$.training_job_name"
      },
    "Create Training Job": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sagemaker:createTrainingJob.sync",
      "Parameters": {
        "TrainingJobName.$": "$.training_job_name",
        "ResourceConfig": {
          "InstanceCount": 1,
          "InstanceType": "${var.training_instance_type}",
          "VolumeSizeInGB": ${var.volume_size_sagemaker}
        },
        "HyperParameters": {
          "test": "test"
        },
        "AlgorithmSpecification": {
          "TrainingImage": "${aws_ecr_repository.ecr_repository.repository_url}",
          "TrainingInputMode": "File"
        },
        "OutputDataConfig": {
          "S3OutputPath": "s3://${module.model_output_bucket.bucket_name}"
        },
        "StoppingCondition": {
          "MaxRuntimeInSeconds": 86400
        },
        "RoleArn": "${aws_iam_role.sagemaker_exec_role.arn}",
        "InputDataConfig": [
        {
          "ChannelName": "training",
          "ContentType": "text/csv",
          "DataSource": {
            "S3DataSource": {
              "S3DataType": "S3Prefix",
              "S3Uri": "s3://${module.training_data_bucket.bucket_name}",
              "S3DataDistributionType": "FullyReplicated"
            }
          }
        }
        ]
      },
      "Next": "Create Model"
    },
    "Create Model": {
      "Parameters": {
        "PrimaryContainer": {
          "Image": "${aws_ecr_repository.ecr_repository.repository_url}",
          "Environment": {},
          "ModelDataUrl.$": "$.ModelArtifacts.S3ModelArtifacts"
        },
        "ExecutionRoleArn": "${aws_iam_role.sagemaker_exec_role.arn}",
        "ModelName.$": "$.TrainingJobName"
      },
      "Resource": "arn:aws:states:::sagemaker:createModel",
      "Type": "Task",
      "ResultPath":"$.taskresult",
      "Next": "Create Endpoint Config"
    },
    "Create Endpoint Config": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sagemaker:createEndpointConfig",
      "Parameters":{
        "EndpointConfigName.$": "$.TrainingJobName",
        "ProductionVariants": [
        {
          "InitialInstanceCount": 1,
          "InstanceType": "${var.inference_instance_type}",
          "ModelName.$": "$.TrainingJobName",
          "VariantName": "AllTraffic"
        }
        ]
      },
      "ResultPath":"$.taskresult",
      "Next":"Create Endpoint"
    },
    "Create Endpoint":{
      "Type":"Task",
      "Resource":"arn:aws:states:::sagemaker:createEndpoint",
      "Parameters":{
        "EndpointConfigName.$": "$.TrainingJobName",
        "EndpointName.$": "$.TrainingJobName"
      },
      "End": true
      }
    }
  }
  EOF

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
}

#################################################
# IAM Roles and Policies for Step Functions
#################################################
// IAM role for Step Functions state machine
data "aws_iam_policy_document" "sf_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.${local.aws_region}.amazonaws.com"]
    }
  }
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sf_exec_role" {
  name               = "${local.project_prefix}-sfn-exec"
  assume_role_policy = data.aws_iam_policy_document.sf_assume_role.json
}

// policy for step function to invoke lambda
data "aws_iam_policy_document" "lambda_invoke" {
  statement {
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      aws_lambda_function.lambda_function.arn,
    ]
  }
}

resource "aws_iam_policy" "lambda_invoke" {
  name   = "${local.project_prefix}-lambda-invoke"
  policy = data.aws_iam_policy_document.lambda_invoke.json
}

resource "aws_iam_role_policy_attachment" "lambda_invoke" {
  role       = aws_iam_role.sf_exec_role.name
  policy_arn = aws_iam_policy.lambda_invoke.arn
}

// policy to invoke sagemaker training job, creating endpoints etc.
data "aws_iam_policy_document" "sm_exec_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sagemaker:CreateTrainingJob",
      "sagemaker:DescribeTrainingJob",
      "sagemaker:StopTrainingJob",
      "sagemaker:createModel",
      "sagemaker:createEndpointConfig",
      "sagemaker:createEndpoint",
      "sagemaker:addTags",
      # "sagemaker:*" # TODO: Test removing this
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "sagemaker:ListTags"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "sagemaker.amazonaws.com",
      ]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "events:PutTargets",
      "events:PutRule",
      "events:DescribeRule"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "sagemaker_policy" {
  name   = "${local.project_prefix}-sagemaker"
  policy = data.aws_iam_policy_document.sm_exec_policy.json
}

resource "aws_iam_role_policy_attachment" "sm_invoke" {
  role       = aws_iam_role.sf_exec_role.name
  policy_arn = aws_iam_policy.sagemaker_policy.arn
}

resource "aws_iam_role_policy_attachment" "cloud_watch_full_access" {
  role       = aws_iam_role.sf_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

#################################################
# IAM Roles and Policies for SageMaker
#################################################

// IAM role for SageMaker training job
data "aws_iam_policy_document" "sagemaker_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sagemaker_exec_role" {
  name               = "${local.project_prefix}-sagemaker-exec"
  assume_role_policy = data.aws_iam_policy_document.sagemaker_assume_role.json
}

// Policies for sagemaker execution training job
data "aws_iam_policy_document" "sm_exec_training_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*" # TODO: Limit scope
    ]
    resources = [
      "${module.training_data_bucket.bucket_arn}",
      "${module.training_data_bucket.bucket_arn}/*",
      "${module.model_output_bucket.bucket_arn}",
      "${module.model_output_bucket.bucket_arn}/*"
    ]
  }
}

resource "aws_iam_policy" "sagemaker_s3_policy" {
  name   = "${local.project_prefix}-sagemaker-s3-policy"
  policy = data.aws_iam_policy_document.sm_exec_training_policy.json
}

resource "aws_iam_role_policy_attachment" "s3_restricted_access" {
  role       = aws_iam_role.sagemaker_exec_role.name
  policy_arn = aws_iam_policy.sagemaker_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}
