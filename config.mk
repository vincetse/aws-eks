region ?= us-east-1
cluster_name = eks-$(region)
stack_prefix = $(cluster_name)
pwd = $(shell pwd)

kubectl = ./kubectl
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
