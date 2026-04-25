{{- define "eg-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "eg-app.fullname" -}}
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

{{- define "eg-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "eg-app.labels" -}}
helm.sh/chart: {{ include "eg-app.chart" . }}
{{ include "eg-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: eg-platform
environment: {{ .Values.namespace }}
{{- end }}

{{- define "eg-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "eg-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "eg-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "eg-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "eg-app.externalSecretsApiVersion" -}}
{{- if .Capabilities.APIVersions.Has "external-secrets.io/v1/ExternalSecret" -}}
external-secrets.io/v1
{{- else if .Capabilities.APIVersions.Has "external-secrets.io/v1beta1/ExternalSecret" -}}
external-secrets.io/v1beta1
{{- else -}}
external-secrets.io/v1beta1
{{- end -}}
{{- end }}
