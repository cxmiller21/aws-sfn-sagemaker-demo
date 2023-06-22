#!/bin/bash

# Run this script from the root of the project
# ./scripts/build_and_push_to_ecr.sh

# Variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
AWS_REGION=us-east-1
ECR_URL=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
ECR_REPO_NAME=ml-pipeline-demo-default

IMAGE_NAME=ml-training
IMAGE_TAG=latest

ECR_URL_FULL=$ECR_URL/$ECR_REPO_NAME:$IMAGE_TAG

cd ./src/container
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL

# Need to build for linux/amd64 on M1 Mac for Sagemaker to run the train job
# Running without the --platform option resulted in an error
# when the images was run on Sagemaker during the training step
docker build -t ml-training --platform=linux/amd64 .
docker tag $IMAGE_NAME:$IMAGE_TAG $ECR_URL_FULL
docker push $ECR_URL_FULL

cd ../../
