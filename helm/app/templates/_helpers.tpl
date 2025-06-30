{{/*
Expand the name of the chart.
*/}}
{{- define "reliability-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "reliability-demo.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "reliability-demo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "reliability-demo.labels" -}}
helm.sh/chart: {{ include "reliability-demo.chart" . }}
{{ include "reliability-demo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "reliability-demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "reliability-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Redis connection string
*/}}
{{- define "reliability-demo.redisHost" -}}
{{- if .Values.redis.enabled }}
{{- printf "%s-redis-master" .Release.Name }}
{{- else }}
{{- .Values.externalRedis.host }}
{{- end }}
{{- end }}

{{/*
Redis port
*/}}
{{- define "reliability-demo.redisPort" -}}
{{- if .Values.redis.enabled }}
6379
{{- else }}
{{- .Values.externalRedis.port | default 6379 }}
{{- end }}
{{- end }}

{{/*
SQL Server connection string
*/}}
{{- define "reliability-demo.sqlServerConnectionString" -}}
{{- if .Values.sqlserver.enabled -}}
{{- printf "Server=%s-sqlserver;Database=ReliabilityDemo;User Id=sa;Password=%s;TrustServerCertificate=true;" .Release.Name .Values.sqlserver.auth.saPassword -}}
{{- else -}}
Server=localhost;Database=ReliabilityDemo;Trusted_Connection=true;
{{- end -}}
{{- end }}

{{/*
Determine if Redis should be enabled based on the pattern
*/}}
{{- define "reliability-demo.redisEnabled" -}}
{{- if eq .Values.config.customerOperation.pattern "Async" -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}