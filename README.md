# aws-sfn-sagemaker-demo

Demo project using AWS Step Functions to Automate an AWS SageMaker workflow

Following this AWS blog post: [link](<https://aws.amazon.com/blogs/machine-learning/define-and-run-machine-learning-pipelines-on-step-functions-using-python-workflow-studio-or-states-language/>)

Current state of the project:

Half complete - The IAM roles and S3 buckets are working but the
training data needs to be uploaded to S3 and I'm not sure which
format the data needs to be in.

TODO:

- Figure out how to upload training data to S3 ([AWS tutorial link with more details](<https://github.com/aws/amazon-sagemaker-examples/blob/be56aa654b9ac7283c4be9c7b2298e475367a7ac/step-functions-data-science-sdk/training_pipeline_pytorch_mnist/training_pipeline_pytorch_mnist.ipynb>))
- Apply Terraform resources and run the State Machine to see if it works
