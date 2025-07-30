{{/*
Expand the name of the chart.
*/}}
{{- define "eshop-microservice.name" -}}
{{- default .Values.microservice.name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "eshop-microservice.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Values.microservice.name .Values.nameOverride }}
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
{{- define "eshop-microservice.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "eshop-microservice.labels" -}}
helm.sh/chart: {{ include "eshop-microservice.chart" . }}
{{ include "eshop-microservice.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: {{ .Values.microservice.name }}
app.kubernetes.io/part-of: eshop
{{- end }}

{{/*
Selector labels
*/}}
{{- define "eshop-microservice.selectorLabels" -}}
app.kubernetes.io/name: {{ include "eshop-microservice.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "eshop-microservice.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "eshop-microservice.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate full image name
*/}}
{{- define "eshop-microservice.image" -}}
{{- $registry := .Values.image.registry -}}
{{- $repository := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{ printf "%s/%s:%s" $registry $repository $tag }}
{{- end }}

{{/*
Generate microservice port
*/}}
{{- define "eshop-microservice.port" -}}
{{ .Values.microservice.port }}
{{- end }}

{{/*
Generate service target port
*/}}
{{- define "eshop-microservice.targetPort" -}}
{{ .Values.service.targetPort | default .Values.microservice.port }}
{{- end }}

{{/*
Generate ConfigMap name
*/}}
{{- define "eshop-microservice.configMapName" -}}
{{ include "eshop-microservice.fullname" . }}-config
{{- end }}

{{/*
Generate Secret name
*/}}
{{- define "eshop-microservice.secretName" -}}
{{ include "eshop-microservice.fullname" . }}-secret
{{- end }}

{{/*
Generate Event Bus subscription client name
*/}}
{{- define "eshop-microservice.eventBusClientName" -}}
{{- if .Values.infrastructure.eventBus.subscriptionClientName }}
{{- .Values.infrastructure.eventBus.subscriptionClientName }}
{{- else }}
{{- .Values.microservice.name | title }}
{{- end }}
{{- end }} 