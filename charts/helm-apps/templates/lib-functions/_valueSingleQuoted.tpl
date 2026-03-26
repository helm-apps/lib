{{- define "lib.valueSingleQuoted" }}
  {{- $result := include "lib.value" . }}
  {{- if ne $result "" }}
    {{- $result | squote }}
  {{- end }}
{{- end }}
