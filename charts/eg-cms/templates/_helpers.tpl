{{- define "eg-cms.name" -}}
{{- default .Chart.Name .Values.application.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "eg-cms.fullname" -}}
{{- if .Values.application.fullnameOverride }}
{{- .Values.application.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.application.name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "eg-cms.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "eg-cms.labels" -}}
helm.sh/chart: {{ include "eg-cms.chart" . }}
{{ include "eg-cms.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.application.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: eg-platform
environment: {{ .Values.environment.namespace }}
{{- with .Values.environment.labels }}
{{- range $k, $v := . }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- define "eg-cms.selectorLabels" -}}
app.kubernetes.io/name: {{ include "eg-cms.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "eg-cms.serviceAccountName" -}}
{{- if .Values.security.serviceAccount.create }}
{{- default (include "eg-cms.fullname" .) .Values.security.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.security.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "eg-cms.externalSecretsApiVersion" -}}
external-secrets.io/v1
{{- end }}