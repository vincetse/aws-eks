include config.mk
stack_name = $(cluster_name)-$(subst .,,$(node_type))-nodes

MAKEFILE = $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))

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
aws-auth:
	$(eval role_arn := $(shell $(CF) describe-stacks --stack-name $(stack_name) --query 'Stacks[0].Outputs[?starts_with(OutputKey,`NodeInstanceRole`)][].OutputValue' --output text))
	echo "$$worker_config_map" > aws-auth-cm.yaml
	KUBECONFIG=./kubeconfig $(kubectl) apply -f aws-auth-cm.yaml
	rm -f aws-auth-cm.yaml

create update:
	$(eval sg := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`SecurityGroups`)][].OutputValue' --output text))
	$(eval vpc := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`VpcId`)][].OutputValue' --output text))
	$(eval subnets := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`SubnetIds`)][].OutputValue' --output text))
	$(CF) $@-stack --stack-name $(stack_name) \
		--template-body $(worker_template) \
		--capabilities CAPABILITY_IAM \
		--parameters \
			ParameterKey=ClusterName,ParameterValue=$(cluster_name) \
			ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue=$(sg) \
			ParameterKey=NodeGroupName,ParameterValue=$(stack_name) \
			ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue=$(min_nodes) \
			ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue=$(max_nodes) \
			ParameterKey=NodeInstanceType,ParameterValue=$(node_type) \
			ParameterKey=NodeImageId,ParameterValue=$(node_ami) \
			ParameterKey=VpcId,ParameterValue=$(vpc) \
			ParameterKey=Subnets,ParameterValue='"$(subnets)"'
	$(CF) wait stack-create-complete --stack-name $(stack_name)
	$(MAKE) -f $(MAKEFILE) aws-auth

delete:
	$(CF) $@-stack --stack-name $(stack_name)
	$(CF) wait stack-$@-complete --stack-name $(stack_name)
