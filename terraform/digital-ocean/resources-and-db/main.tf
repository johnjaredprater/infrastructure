provider "kubernetes" {
  config_path = "~/.kube/config"
}


data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "gym-track"
    key    = "infrastructure/terraform.tfstate"
    region = var.region
    endpoints = {
      s3 = "https://lon1.digitaloceanspaces.com"
    }
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
  }
}


resource "kubernetes_secret" "db_credentials" {
  metadata {
    name = "db-credentials"
  }

  data = {
    username = digitalocean_database_cluster.gym-track-core.user
    password = digitalocean_database_cluster.gym-track-core.password
    uri      = digitalocean_database_cluster.gym-track-core.private_uri
    host     = digitalocean_database_cluster.gym-track-core.private_host
    port     = digitalocean_database_cluster.gym-track-core.port
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

resource "digitalocean_database_cluster" "gym-track-core" {
  name                 = "gym-track-db"
  engine               = "mysql"
  version              = "8"
  size                 = "db-s-1vcpu-1gb"
  region               = var.region
  node_count           = 1
  private_network_uuid = data.terraform_remote_state.infrastructure.outputs.vpc_id
  project_id           = data.terraform_remote_state.infrastructure.outputs.project_id
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.publishService.enabled"
    value = "true"
  }

  set {
    name  = "controller.service.annotations.service.beta.kubernetes.io/do-loadbalancer-name"
    value = "k8s-lb"
  }

  set {
    name  = "controller.service.annotations.service.beta.kubernetes.io/do-loadbalancer-protocol"
    value = "https"
  }

  set {
    name  = "controller.service.annotations.service.beta.kubernetes.io/do-loadbalancer-http-to-https-redirect"
    value = "true"
  }

}

resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert-manager" {
  name = "cert-manager"

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [kubernetes_namespace.cert-manager]
}
