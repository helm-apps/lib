{{- define "lib.isTrue" }}
  {{- ternary true "" (include "lib.value" . | eq "true") }}
{{- end }}
