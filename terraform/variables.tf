variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "ml-pipeline-demo"
}

variable "training_instance_type" {
  type        = string
  description = "Instance type for training the ML model"
  default     = "ml.m5.xlarge"
}

variable "inference_instance_type" {
  type        = string
  description = "Instance type for training the ML model"
  default     = "ml.c5.large"
}

variable "handler_path" {
  type        = string
  description = "Path of the lambda handler"
  default     = "../src/lambda_function"
}

variable "volume_size_sagemaker" {
  type        = number
  description = "Volume size SageMaker instance in GB"
  default     = 5
}
