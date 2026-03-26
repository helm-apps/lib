{{- define "lib.generateLabels" }}
  {{- $ := index . 0 }}
  {{- $relativeScope := index . 1 }}
  {{- $appName := index . 2 }}
app: {{ $appName | quote }}
chart: {{ $.Chart.Name | trunc 63 | quote }}
repo: {{ $.Values.global.repo | default $.Release.Name | trunc 63 | quote }}
{{- end }}
