# Below are instruction to run the project

1. Navigate to the project directory:
>cd azure-vm-project

2. Initialize Terraform:
>terraform init

3 .Plan and apply for each environment:
>terraform plan -var-file=environments/test.tfvars
>terraform apply -var-file=environments/test.tfvars
