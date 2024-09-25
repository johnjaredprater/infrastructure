provider "aws" {
  region = var.region
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "gym-prod"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "eks-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  cluster_endpoint_public_access           = true # Allows kubectl to work
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    eks-managed = {
      name = "eks-managed"

      instance_types = ["t3.medium"]

      min_size          = 1
      max_size          = 2
      desired_size      = 1
      privateNetworking = true
    }
  }
}


# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}



resource "random_password" "db_password" {
  length  = 16
  special = true
}


resource "kubernetes_secret" "db_credentials" {
  metadata {
    name = "db-credentials"
  }

  data = {
    username = "admin"
    password = random_password.db_password.result
  }
}


resource "kubernetes_secret" "firebase-credentials" {
  metadata {
    name = "firebase-credentials"
  }

  data = {
    "firebase-key.json" = base64encode(file(var.firebase-credentials-path))
  }
}

resource "kubernetes_service_account" "secret_service_account" {
  metadata {
    name      = "secret-service-account"
    namespace = "default"
  }
}

resource "kubernetes_role" "secret_reader" {
  metadata {
    name      = "secret-reader"
    namespace = "default"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding" "secret_reader_binding" {
  metadata {
    name      = "read-secrets-binding"
    namespace = "default"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.secret_service_account.metadata[0].name
    namespace = "default"
  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role.secret_reader.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}


resource "aws_db_subnet_group" "example" {
  name       = "gym-track-core-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "gym-track-core-subnet-group"
  }
}


resource "aws_security_group" "rds_sg" {
  vpc_id = module.vpc.vpc_id
  name   = "rds_sg"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Adjust this based on your needs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_db_instance" "gym-track-core" {
  apply_immediately      = true
  allocated_storage      = 20
  identifier             = "gym-track-core"
  db_name                = "gymtrack"
  engine                 = "mariadb"
  engine_version         = "10.11.8"
  instance_class         = "db.t4g.micro"
  username               = kubernetes_secret.db_credentials.data.username
  password               = kubernetes_secret.db_credentials.data.password
  parameter_group_name   = "default.mariadb10.11"
  db_subnet_group_name   = aws_db_subnet_group.example.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}


module "lb_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "amazon_eks_load_balancer_controller_role"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "kubernetes_service_account" "service-account" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}


resource "helm_release" "alb-controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    kubernetes_service_account.service-account
  ]

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.${var.region}.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.service-account.metadata.name
  }

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
}