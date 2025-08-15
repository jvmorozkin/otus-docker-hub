{{/* Генерация полного имени */}}
{{- define "otus-app.fullname" -}}
{{- printf "%s-%s" .Release.Name "app" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Общие метки */}}
{{- define "otus-app.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "otus-app.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Селектор метки */}}
{{- define "otus-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "otus-app.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}