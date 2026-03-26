{{- define "lib.generateSecretEnvVars" }}
{{- $ := index . 0 }}
{{-  if $.Values.global.configFlantLibVariableUppercaseEnvs }}
{{- include "lib.generateSecretData" (append . true) }}
{{- else }}
{{- include "lib.generateSecretData" . }}
{{- end }}
{{- end }}
