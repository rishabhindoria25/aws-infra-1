# Setting up AWS infrastructure using Terraform

## :package: Prerequisites

Install:

- `aws-cli` [[link](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)]
- `terraform` [[link](https://developer.hashicorp.com/terraform/downloads)]

## :arrow_heading_down: Installation

Prerequisite: ssh configured on your local system to clone this project using ssh.

> Clone the server side API service using the following command:

shell
git clone git@github.com:AndroXmeda/aws-infra.git


> To clone the forked repository, use the following command:

shell
git clone git@github.com:rishabhindoria25/aws-infra.git



> Configure the aws-cli [[link](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)]


## :rocket: AWS infrastructure setup

>Initialize Terraform

shell
  terraform init


> To create an execution plan with default configurations and to apply it

shell
  terraform plan
  terraform apply


> To destroy all managed objects created by the plan
> 
shell
  terraform destroy


## :ninja: Author

[Rishabh Indoria](mailto:indoria.r@northeastern.edu)

## :scroll: License

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
