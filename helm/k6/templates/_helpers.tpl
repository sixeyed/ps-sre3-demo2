{{/*
Expand the name of the chart.
*/}}
{{- define "k6-tests.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "k6-tests.fullname" -}}
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
{{- define "k6-tests.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "k6-tests.labels" -}}
helm.sh/chart: {{ include "k6-tests.chart" . }}
{{ include "k6-tests.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "k6-tests.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k6-tests.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Generate random suffix for job names
*/}}
{{- define "k6-tests.randomSuffix" -}}
{{- randAlphaNum (int (.Values.job.randomSuffixLength | default 5)) | lower }}
{{- end }}

{{/*
Generate sequential test command
*/}}
{{- define "k6-tests.sequentialCommand" -}}
{{- $commands := list "echo '🧪 Starting K6 Test Suite...'" }}
{{- range $index, $test := .Values.tests.sequential.sequence }}
{{- $step := add $index 1 }}
{{- $commands = append $commands (printf "echo '%d/%d Running %s (%s)...'" $step (len $.Values.tests.sequential.sequence) $test.name $test.duration) }}
{{- $commands = append $commands (printf "k6 run /scripts/%s" $test.script) }}
{{- end }}
{{- $commands = append $commands "echo '✅ All tests completed successfully!'" }}
{{- join " ; " $commands }}
{{- end }}