# AWS Step Function and Sagemaker ML Pipeline Demo

This project uses AWS Step Functions to Automate an AWS SageMaker workflow.

I heavily references this AWS sample project - [link](<https://github.com/aws-samples/amazon-sagemaker-ml-pipeline-deploy-with-terraform/tree/main>). I did make a fair amount of Terraform changes to clean the project up a bit and make the project successfully run for me. I also added some helper scripts to make running and cleaning up the project easier.

## Getting Started

### Terraform

Create the AWS resources for the project.

```bash
cd terraform
# Update the versions.tf backend "s3" bucket name to your own bucket
terraform init
terraform apply # Enter "yes" when prompted
```

### Docker

Build and publish the Docker image to ECR that will be used for the SageMaker training job. This script does not need to be modified.

```bash
./scripts/build_and_push_to_ecr.sh
```

## Running the ML Pipeline

1. Login to the AWS console and navigate to the Step Functions service
2. Click on the `ml-pipeline-demo-default-state-machine` state machine created by Terraform
3. Click the `Start execution` button and add a custom message or leave default value
4. Wait for State Machine to complete (~2 minutes)
5. View Sagemaker training job and endpoint in the AWS console
6. Run the `scripts/test_endpoint.py` script to verify the endpoint is working

## Cleanup

The AWS resources created by Terraform can be destroyed by running the following script.

```bash
./scripts/cleanup.sh
```

This script will delete the Sagemaker endpoint and the AWS resources created by Terraform. The S3 bucket and ECR repository created by Terraform **will also be deleted** due to the `force_destroy = true` being set on the resources.
