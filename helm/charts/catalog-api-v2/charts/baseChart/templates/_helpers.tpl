{{/*
Expand the name of the chart.
*/}}
{{- define "application.name" -}}
{{- default .Values.application.name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "application.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Values.application.name .Values.nameOverride }}
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
{{- define "application.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "application.labels" -}}
helm.sh/chart: {{ include "application.chart" . }}
{{ include "application.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: {{ .Values.application.name }}

{{- end }}

{{/*
Selector labels
*/}}
{{- define "application.selectorLabels" -}}
app.kubernetes.io/name: {{ include "application.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "application.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "application.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate full image name
*/}}
{{- define "application.image" -}}
{{- $registry := .Values.image.registry -}}
{{- $repository := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{ printf "%s/%s:%s" $registry $repository $tag }}
{{- end }}

{{/*
Generate application port
*/}}
{{- define "application.port" -}}
{{ .Values.application.port }}
{{- end }}

{{/*
Generate service target port
*/}}
{{- define "application.targetPort" -}}
{{ .Values.service.targetPort | default .Values.application.port }}
{{- end }}

{{/*
Generate ConfigMap name
*/}}
{{- define "application.configMapName" -}}
{{ include "application.fullname" . }}-config
{{- end }}

{{/*
Generate Secret name
*/}}
{{- define "application.secretName" -}}
{{ include "application.fullname" . }}-secret
{{- end }}

{{/*
Generate Event Bus subscription client name
*/}}
{{- define "application.eventBusClientName" -}}
{{- if .Values.sharedServices.rabbitmq.subscriptionClientName }}
{{- .Values.sharedServices.rabbitmq.subscriptionClientName }}
{{- else }}
{{- .Values.application.name | title }}
{{- end }}
{{- end }}

{{/*
Database-specific labels (overrides component to 'database')
*/}}
{{- define "application.databaseLabels" -}}
helm.sh/chart: {{ include "application.chart" . }}
{{ include "application.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: database
{{- end }}

{{/*
Generate PostgreSQL connection string
*/}}
{{- define "application.postgresqlConnectionString" -}}
{{- if .Values.postgresql.connectionString -}}
{{- .Values.postgresql.connectionString -}}
{{- else -}}
Host={{ .Values.postgresql.serviceName | default (printf "%s-postgresql" .Release.Name) }};Port={{ .Values.postgresql.port | default 5432 }};Database={{ .Values.postgresql.auth.database }};Username={{ .Values.postgresql.auth.username }};Password={{ .Values.postgresql.auth.password }}
{{- end -}}
{{- end }}