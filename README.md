# AWS EKS

Automation to get an [AWS EKS](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) cluster going.

## Quick Start

```
# create a EKS Kubernetes cluster with in us-east-1
# with one t2.small and one t2.medium node.
make create

# delete the cluster
make delete
```

## Going Deeper

### Download Client Binaries

The [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) mentions 2 binaries--`kubectl` and `heptio-authenticator-aws`--and this just downloads them into the current directory.

```
make -f eks.Makefile binaries
```

### Single Node Type

```
# Create the EKS master nodes first
make -f eks.Makefile create

# Generate the kubeconfig file for kubectl
make -f eks.Makefile kubeconfig

# Create t2.medium worker nodes in an autoscaling group
# with a minimum of 1 node and a maximum of 2 nodes
make -f workers.Makefile create node_type=t2.medium min_node=1 max_node=2

# Using the Kubernetes cluster
export KUBECONFIG=$(pwd)/kubeconfig PATH=.:${PATH}
kubectl get nodes

# Shut down the worker nodes
make -f workers.Makefile create node_type=t2.medium

# Shut down the EKS master nodes
make -f eks.Makefile delete
```

### Multiple Node Types

```
# Create the EKS master nodes first
make -f eks.Makefile create

# Generate the kubeconfig file for kubectl
make -f eks.Makefile kubeconfig

# Create t2.medium worker nodes in an autoscaling group
# with a minimum of 1 node and a maximum of 2 nodes
make -f workers.Makefile create node_type=t2.medium min_node=1 max_node=2

# Add 10 t2.small worker nodes
make -f workers.Makefile create node_type=t2.small min_node=10 max_node=10

# Using the Kubernetes cluster
export KUBECONFIG=$(pwd)/kubeconfig PATH=.:${PATH}
kubectl get nodes

# Shut down the worker nodes
make -f workers.Makefile create node_type=t2.medium
make -f workers.Makefile create node_type=t2.small

# Shut down the EKS master nodes
make -f eks.Makefile delete
```

## References

1. https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html
