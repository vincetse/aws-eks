# AWS EKS

Automation to get an [AWS EKS](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) cluster going.


## Instructions

```
# Create one-time prerequisites: the VPC, subnets
make create

# Create the Kubernetes cluster
make eks_create

# Delete the Kubernetes cluster
make eks_delete

# Delete the prereqs
make delete
```

## References

1. https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html
