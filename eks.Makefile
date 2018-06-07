include config.mk

#vpc_template = https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-vpc-sample.yaml
vpc_template = file://eks.yaml
kubectl_url = https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/kubectl
heptio_url = https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/heptio-authenticator-aws

binaries:
	curl -o $(kubectl) $(kubectl_url)
	chmod +x $(kubectl)
	curl -o $(heptio) $(heptio_url)
	chmod +x $(heptio)

create update:
	$(CF) $@-stack --stack-name $(stack_prefix)-vpc \
		--template-body $(vpc_template) \
		--capabilities CAPABILITY_IAM \
		--parameters \
			ParameterKey=ClusterName,ParameterValue=$(cluster_name)
	$(CF) wait stack-$@-complete --stack-name $(stack_prefix)-vpc

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
	$(eval ca := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`EksCertificateAuthorityData`)][].OutputValue' --output text))
	$(eval endpoint := $(shell $(CF) describe-stacks --stack-name $(stack_prefix)-vpc --query 'Stacks[0].Outputs[?starts_with(OutputKey,`EksEndpoint`)][].OutputValue' --output text))
	@echo "$$kubeconfig_content" > $@
	@echo "Run the following in your shell:"
	@echo 'export KUBECONFIG=$(pwd)/$@ PATH=$(pwd):$${PATH}'

shell: kubeconfig
	KUBECONFIG=kubeconfig $(kubectl) run shell	--tty -i	--rm	--image=alpine:3.7 /bin/sh

clean:
	rm -f kubeconfig $(kubectl) $(heptio)

.PHONY: kubeconfig clean
