{{- define "lib.isFalse" }}
  {{- ternary "" true (include "lib.value" . | eq "true") }}
{{- end }}
