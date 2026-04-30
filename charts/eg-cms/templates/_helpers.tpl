{{- define "eg-cms.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "eg-cms.fullname" -}}
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

{{- define "eg-cms.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "eg-cms.labels" -}}
helm.sh/chart: {{ include "eg-cms.chart" . }}
{{ include "eg-cms.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: eg-platform
environment: {{ .Values.namespace }}
{{- end }}

{{- define "eg-cms.selectorLabels" -}}
app.kubernetes.io/name: {{ include "eg-cms.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "eg-cms.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "eg-cms.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{- define "eg-cms.externalSecretsApiVersion" -}}
external-secrets.io/v1
{{- end }}