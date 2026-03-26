{{- define "lib.valueQuoted" }}
  {{- $result := include "lib.value" . }}
  {{- if ne $result "" }}
    {{- $result | quote }}
  {{- end }}
{{- end }}
