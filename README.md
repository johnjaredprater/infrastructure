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

Install the Digital Ocean CLI tool & export an access token:
```bash
brew install doctl
doctl auth init -t $(cat ~/digital-ocean-token)
export DIGITALOCEAN_ACCESS_TOKEN=$(cat ~/digital-ocean-token)
```

To store terraform state remotely in a Digital Ocean space, our terraform can
make use of the s3 api. So export the following environment variables to 
grant access (this is not for interfacing with AWS!):
```
export AWS_ACCESS_KEY_ID=$(cat ~/digital-ocean-spaces-access-key)
export AWS_SECRET_ACCESS_KEY=$(cat ~/digital-ocean-spaces-secret-key)
```

To spin up the Kubernetes Cluster, use:
```bash
cd terraform/digital-ocean/kubernetes-cluster

terraform init
terraform apply
```

To add the resources and database cluster use
```bash
cd terraform/digital-ocean/resources-and-db

doctl kubernetes cluster kubeconfig save gym-track
kubectl config get-contexts
kubectl config use-context ...
export KUBE_CONFIG_PATH=~/.kube/config

terraform init
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
nc <host> <port>
```
