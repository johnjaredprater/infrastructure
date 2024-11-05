# infrastructure

Currently, the infrastructure must be deployed using terraform locally.

Install pre-commit & set it up:
```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

Install Terraform & login:
```bash
brew install hashicorp/tap/terraform
terraform login

brew install terraform-docs
```

To spin up the EKS cluster, use:
```bash
cd terraform/eks-cluster
terraform init
terraform plan
terraform apply
```

To add the RDS database, the load balancer controller and some secrets use
```bash
cd terraform/resources

aws eks --region eu-west-2 update-kubeconfig --name gym-prod
export KUBE_CONFIG_PATH=~/.kube/config

terraform init
terraform plan
terraform apply
```

To deploy the relevant applications on the cluster, bootstrap flux:

```bash
kubectl config current-context

export GITHUB_TOKEN=<token>
flux bootstrap github \
  --token-auth \
  --owner=johnjaredprater \
  --repository=infrastructure \
  --branch=main \
  --path=./deploy \
  --personal \
  --components="source-controller,kustomize-controller"
```

Finally modify the dmomain dns records to point the domain name to the load balancer 

## Useful Commands

Some useful kubectl commands:

```bash
kubectl config current-context
kubectl cluster-info

kubectl get deployments
kubectl get services

kubectl get all -A
```

Or use (k9s)[https://k9scli.io/topics/commands/] to inspect running pods

view resource aliases with `ctrl + a`, and `d` to describe a selected resource. `ctrl + c` to quit the application

## Debug

To spin up a simple pod for testing the infrastructure, use:
```bash
kubectl run -i --tty --rm debug --image=busybox --restart=Never -- sh
```

For example you could test the connection to the DB with:
```
nc gym-track-core.cziymq0g8e9k.eu-west-2.rds.amazonaws.com 3306
```
