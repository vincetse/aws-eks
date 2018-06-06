region ?= us-east-1
cluster_name = eks-$(region)
stack_prefix = $(cluster_name)
pwd = $(shell pwd)

#vpc_template = https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-vpc-sample.yaml
vpc_template = file://vpc.yaml
kubectl_url = https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/kubectl
kubectl = ./kubectl
heptio_url = https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/heptio-authenticator-aws
heptio = ./heptio-authenticator-aws

# Worker Nodes
#worker_template = https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-nodegroup.yaml
worker_template = file://amazon-eks-nodegroup.yaml
min_nodes = 1
max_nodes = 1
node_type = t2.small
node_ami = ami-dea4d5a1

AWS = aws --region $(region)
CF = $(AWS) cloudformation
EKS = $(AWS) eks

export PATH := .:$(PATH)

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
	$(eval sg := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`SecurityGroups`)][].OutputValue' --output text))
	$(eval vpc := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`VpcId`)][].OutputValue' --output text))
	$(eval subnets := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`SubnetIds`)][].OutputValue' --output text))
	$(eval role_arn := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`ServiceRoleArn`)][].OutputValue' --output text))
	#$(eval account_id := $(shell $(AWS) sts get-caller-identity --output text --query 'Account'))
	$(EKS) create-cluster --name $(cluster_name) \
		--role-arn $(role_arn) \
		--resources-vpc-config subnetIds=$(subnets),securityGroupIds=$(sg)

define worker_config_map
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: $(role_arn)
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
endef
export worker_config_map
nodes_create:
	$(eval sg := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`SecurityGroups`)][].OutputValue' --output text))
	$(eval vpc := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`VpcId`)][].OutputValue' --output text))
	$(eval subnets := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`SubnetIds`)][].OutputValue' --output text))
	$(CF) create-stack --stack-name $(cluster_name)-worker-nodes \
		--template-body $(worker_template) \
		--capabilities CAPABILITY_IAM \
		--parameters \
			ParameterKey=ClusterName,ParameterValue=$(cluster_name) \
			ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue=$(sg) \
			ParameterKey=NodeGroupName,ParameterValue=$(cluster_name)-nodes \
			ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue=$(min_nodes) \
			ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue=$(max_nodes) \
			ParameterKey=NodeInstanceType,ParameterValue=$(node_type) \
			ParameterKey=NodeImageId,ParameterValue=$(node_ami) \
			ParameterKey=VpcId,ParameterValue=$(vpc) \
			ParameterKey=Subnets,ParameterValue='"$(subnets)"'
	$(CF) wait stack-create-complete --stack-name $(cluster_name)-worker-nodes
	$(eval role_arn := $(shell $(CF) describe-stacks --stack-name $(cluster_name)-worker-nodes --query 'Stacks[0].Outputs[?starts_with(OutputKey,`NodeInstanceRole`)][].OutputValue' --output text))
	echo "$$worker_config_map" > aws-auth-cm.yaml
	KUBECONFIG=./kubeconfig $(kubectl) apply -f aws-auth-cm.yaml
	rm -f aws-auth-cm.yaml

nodes_delete:
	$(CF) delete-stack --stack-name $(cluster_name)-worker-nodes
	$(CF) wait stack-delete-complete --stack-name $(cluster_name)-worker-nodes

eks_delete:
	$(EKS) delete-cluster --name $(cluster_name)

delete:
	$(CF) delete-stack --stack-name $(stack_prefix)-vpc
	$(CF) wait stack-$@-complete --stack-name $(stack_prefix)-vpc

define kubeconfig_content
apiVersion: v1
clusters:
- cluster:
    server: $(endpoint)
    certificate-authority-data: $(ca)
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: heptio-authenticator-aws
      args:
        - 'token'
        - '-i'
        - '$(cluster_name)'
        # - '-r'
        # - '<role-arn>'
endef
export kubeconfig_content
kubeconfig:
	$(eval ca := $(shell $(EKS) describe-cluster --name $(cluster_name) --query 'cluster.certificateAuthority.data' --output text))
	$(eval endpoint := $(shell $(EKS) describe-cluster --name $(cluster_name) --query 'cluster.endpoint' --output text))
	$(eval role := foo)
	@echo "$$kubeconfig_content" > $@
	@echo "Run the following in your shell:"
	@echo 'export KUBECONFIG=$(pwd)/$@ PATH=$(pwd):$${PATH}'

shell: kubeconfig
	KUBECONFIG=kubeconfig $(kubectl) run shell  --tty -i  --rm  --image=alpine:3.7 /bin/sh

clean:
	rm -f kubeconfig $(kubectl) $(heptio)

.PHONY: kubeconfig clean
