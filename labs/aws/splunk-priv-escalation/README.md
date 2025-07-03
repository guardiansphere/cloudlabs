# Splunk Privilege Escalation Lab

This Terraform configuration provisions a vulnerable Splunk server on AWS. The EC2 instance receives an IAM role that can assume an administrator role, allowing privilege escalation if the host is compromised. CloudTrail is enabled with logs stored in S3 for auditing.

## Resources Created
- EC2 instance running Splunk (Amazon Linux 2 with a simple install script)
- IAM instance role that can assume an admin role
- Admin IAM role with `AdministratorAccess`
- S3 bucket for CloudTrail logs
- CloudTrail trail writing to the bucket

## Usage
1. Install [Terraform](https://terraform.io/) and configure the AWS CLI with valid credentials.
2. Provide the name of an existing EC2 key pair:
   ```bash
   terraform init
   terraform apply -var="key_name=<my-key-pair>"
   ```
3. After a few minutes Terraform will output the public IP address of the Splunk server.

## Simulating Compromise and Escalation
1. SSH to the instance using the key pair provided.
2. Suppose Splunk is exploited and you obtain shell access. Use the AWS CLI to assume the attached admin role:
   ```bash
   aws sts assume-role \
       --role-arn $(terraform output -raw admin_role_arn) \
       --role-session-name attacker
   ```
3. The credentials returned grant full administrator privileges.

## Estimated Cost
Running this lab with a `t2.micro` instance and CloudTrail enabled should cost under **$1/day**. Prices vary by region. Remember to destroy resources when finished.

## Teardown
Remove all resources with:
```bash
terraform destroy
```
