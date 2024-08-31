# infrastructure

More docs are here: (eksctl - getting started)[https://eksctl.io/getting-started/]

To spin up the gym-prod EKS cluster, use:
```bash
export GITHUB_TOKEN=<your gitlab token>
eksctl create cluster -f eks/gym-prod/cluster-config.yaml
```

To delete an existing cluster, use:
```bash
eksctl delete cluster --region=eu-north-1 --name=gym-prod
```

To scale the managed nodegroup, use:
```bash
eksctl scale nodegroup --cluster=gym-prod --nodes=5 --nodes-max=6 --name=eks-managed --wait
```

## Useful Commands

Some useful kubectl commands:

```bash
kubectl cluster-info

kubectl get deployments
kubectl describe deployments web-server

kubectl get services
kubectl describe services web-server-service

kubectl get all -A
```

Or use (k9s)[https://k9scli.io/topics/commands/] to inspect running pods

view resource aliases with `ctrl + a`, and `d` to describe a selected resource. `ctrl + c` to quit the application

## Debug

Can get stack info with:

```bash
eksctl utils describe-stacks --region=eu-north-1 --cluster=gym-prod
```

Can view logs with:
```bash
aws cloudformation describe-stack-set-operation \
  --stack-set-name eksctl-gym-prod-nodegroup-eks-mng \
  --operation-id xxxx-xxxx-xxxxx
```