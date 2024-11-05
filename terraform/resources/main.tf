data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "eks-terraform-state-gym-track"
    key    = "infrastructure/terraform.tfstate"
    region = "eu-west-2"
  }
}


resource "random_password" "db_password" {
  length  = 16
  special = true # TODO: only allow rds-allowed characters
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
  subnet_ids = data.terraform_remote_state.infrastructure.outputs.vpc_private_subnets

  tags = {
    Name = "gym-track-core-subnet-group"
  }
}


resource "aws_security_group" "rds_sg" {
  vpc_id = data.terraform_remote_state.infrastructure.outputs.vpc_id
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


module "aws_load_balancer_controller_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.1"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}


resource "kubernetes_service_account" "aws_lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.aws_load_balancer_controller_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}


resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    kubernetes_service_account.aws_lb_controller
  ]

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = data.terraform_remote_state.infrastructure.outputs.vpc_id
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
    value = kubernetes_service_account.aws_lb_controller.metadata[0].name
  }

  set {
    name  = "clusterName"
    value = "gym-prod"
  }
}