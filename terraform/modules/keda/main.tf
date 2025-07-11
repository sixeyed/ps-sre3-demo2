resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  namespace  = "keda-system"
  version    = "2.15.1"

  create_namespace = true

  set {
    name  = "crds.install"
    value = "true"
  }

  set {
    name  = "operator.replicaCount" 
    value = "2"
  }

  set {
    name  = "metricsServer.replicaCount"
    value = "2"
  }

  # Schedule KEDA on default nodes
  set {
    name  = "operator.nodeSelector.nodepool"
    value = "default"
  }

  set {
    name  = "metricsServer.nodeSelector.nodepool"
    value = "default"
  }
}