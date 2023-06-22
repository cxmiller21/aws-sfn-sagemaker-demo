locals {
  account_id = data.aws_caller_identity.current.account_id
  aws_region = data.aws_region.current.name

  project_prefix    = "${var.project_name}-${terraform.workspace}"
  region_account_id = "${local.aws_region}-${local.account_id}"

  s3_training_data_bucket_name = "${local.project_prefix}-training-data-${local.region_account_id}"
  s3_output_models_bucket_name = "${local.project_prefix}-output-models-${local.region_account_id}"

  s3_object_training_data = "../data/iris.csv"

  lambda_function_name = "config-${local.project_prefix}"
  lambda_folder        = "${var.handler_path}/"
  lambda_zip_filename  = "${var.handler_path}.zip"
}
