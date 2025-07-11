output "keda_namespace" {
  value = helm_release.keda.namespace
}

output "keda_version" {
  value = helm_release.keda.version
}