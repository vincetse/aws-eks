region ?= us-east-1
cluster_name = eks-$(region)
stack_prefix = $(cluster_name)

#vpc_template = https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-vpc-sample.yaml
vpc_template = file://vpc.yaml
kubectl_url = https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/kubectl
kubectl = ./kubectl
heptio_url = https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/heptio-authenticator-aws
heptio = ./heptio-authenticator-aws

AWS = aws --region $(region)
CF = $(AWS) cloudformation
EKS = $(AWS) eks

setup:
	curl -o $(kubectl) $(kubectl_url)
	chmod +x $(kubectl)
	curl -o $(heptio) $(heptio_url)
	chmod +x $(heptio)

create update:
	$(CF) $@-stack --stack-name $(stack_prefix)-vpc \
		--template-body $(vpc_template) \
		--capabilities CAPABILITY_IAM
	$(CF) wait stack-$@-complete --stack-name $(stack_prefix)-vpc

eks_create:
	$(eval sg := $(shell $(CF) describe-stacks --stack-name eks-us-east-1-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`SecurityGroups`)][].OutputValue' --output text))
	$(eval vpc := $(shell $(CF) describe-stacks --stack-name eks-us-east-1-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`VpcId`)][].OutputValue' --output text))
	$(eval subnets := $(shell $(CF) describe-stacks --stack-name eks-us-east-1-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`SubnetIds`)][].OutputValue' --output text))
	$(eval role_arn := $(shell $(CF) describe-stacks --stack-name eks-us-east-1-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`ServiceRoleArn`)][].OutputValue' --output text))
	#$(eval account_id := $(shell $(AWS) sts get-caller-identity --output text --query 'Account'))
	$(EKS) create-cluster --name $(cluster_name) \
		--role-arn $(role_arn) \
		--resources-vpc-config subnetIds=$(subnets),securityGroupIds=$(sg)

eks_delete:
	$(EKS) delete-cluster --name $(cluster_name)

delete:
	$(CF) delete-stack --stack-name $(stack_prefix)-vpc
	$(CF) wait stack-$@-complete --stack-name $(stack_prefix)-vpc
