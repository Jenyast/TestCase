provider "kubernetes" {
  config_path = "~/.kube/config" 
}


provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "kubernetes_namespace" "httpd" {
  metadata {
    name = "httpd"
  }
}

resource "helm_release" "istio_base" {
  name             = "istio-base"
  chart            = "base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true

  version = "1.20.2"
}


resource "helm_release" "istiod" {
  name             = "istio"
  chart            = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true

  version = "1.20.2"
}

resource "helm_release" "istio_ingress" {
  name             = "istio-ingressgateway"
  chart            = "gateway"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  namespace        = "istio-system"
  create_namespace = true

  version = "1.20.2"

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
}

# Deployment
resource "kubernetes_manifest" "httpd_deployment" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name = "httpd-deployment"
      namespace = "httpd"
    }
    spec = {
      selector = {
        matchLabels = {
          app = "httpd"
        }
      }
      replicas = 2
      template = {
        metadata = {
          labels = {
            app = "httpd"
          }
        }
        spec = {
          containers = [
            {
              name  = "httpd"
              image = "httpd:latest"
              ports  = [
                {
                  containerPort = 80
                }
              ]
            }
          ]
        }
      }
    }
  }
}

# Service
resource "kubernetes_manifest" "httpd_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name   = "httpd"
      namespace = "httpd"
      labels = {
        app = "httpd"
      }
    }
    spec = {
      ports = [
        {
          port     = 80
          protocol = "TCP"
        }
      ]
      selector = {
        app = "httpd"
      }
    }
  }
}
# Gateway
resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name = "gateway"
      namespace = "istio-system"
    }
    spec = {
      selector = {
        app = "istio-ingressgateway"
      }
      servers = [
        {
          port = {
            number   = 80
            name     = "http"
            protocol = "HTTP"
          }
          hosts = ["*"]
        }
      ]
    }
  }
}

# VirtualService
resource "kubernetes_manifest" "virtual_service" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name = "vs-ingress"
      namespace = "istio-system"
    }
    spec = {
      hosts    = ["*"]
      gateways = ["gateway"]
      http     = [
        {
          route = [
            {
              destination = {
                host = "httpd.httpd.svc.cluster.local"
              }
            }
          ]
        }
      ]
    }
  }
}