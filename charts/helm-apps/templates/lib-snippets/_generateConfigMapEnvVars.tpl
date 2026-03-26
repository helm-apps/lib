{{- define "lib.generateConfigMapEnvVars" }}
{{- $ := index . 0 }}
{{-  if $.Values.global.configFlantLibVariableUppercaseEnvs }}
{{- include "lib.generateConfigMapData" (append . true) }}
{{- else }}
{{- include "lib.generateConfigMapData" . }}
{{- end }}
{{- end }}
