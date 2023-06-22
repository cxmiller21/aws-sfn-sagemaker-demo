#!/bin/bash

echo "Cleaning up AWS resources..."

# Sagemaker cleanup
echo "Finding and deleting the projects Sagemaker endpoint..."
sagemaker_endpoints=$(aws sagemaker list-endpoints | jq -r '.Endpoints[].EndpointName')
project_endpoint=""
for endpoint in $(echo $sagemaker_endpoints)
  do
    # Check if the endpoint name contains the project name
    if [[ $endpoint == "ml-pipeline-demo"* ]]; then
      project_endpoint=$endpoint
    fi
  done

if [ -z "${project_endpoint}" ]; then
  echo "No Sagemaker endpoint found for the project"
  echo "Continuing to delete Terraform resources..."
else
  echo "Deleting Sagemaker endpoint ${project_endpoint}"
  aws sagemaker delete-endpoint --endpoint-name $project_endpoint
  echo "Sagemaker endpoint successfully deleted!"
fi

# Terraform cleanup
echo "Cleaning up Terraform resources..."
cd ./terraform
terraform destroy -auto-approve
cd ../
echo "Terraform resources successfully deleted!"

echo "Project cleanup complete!"
