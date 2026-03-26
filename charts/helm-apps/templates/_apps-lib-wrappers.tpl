{{- define "apps.generateContainerEnvVars" }}
{{- $ := index . 0 }}
{{- include "apps-utils.enterScope" (list $ "envVars") }}
{{- include "lib.generateContainerEnvVars" . }}
{{- include "apps-utils.leaveScope" $ }}
{{- end }}

{{- define "apps.generateSecretEnvVars" }}
{{- $ := index . 0 }}
{{- include "apps-utils.enterScope" (list $ "secretEnvVars") }}
{{- include "lib.generateSecretEnvVars" . }}
{{- include "apps-utils.leaveScope" $ }}
{{- end }}

{{- define "apps.generateConfigMapEnvVars" }}
{{- $ := index . 0 }}
{{- include "apps-utils.enterScope" (list $ "EnvVars") }}
{{- include "lib.generateConfigMapEnvVars" . }}
{{- include "apps-utils.leaveScope" $ }}
{{- end }}

{{- define "apps.generateConfigMapData" }}
{{- $ := index . 0 }}
{{- include "apps-utils.enterScope" (list $ "data") }}
{{- include "lib.generateConfigMapData" . }}
{{- include "apps-utils.leaveScope" $ }}
{{- end }}

{{- define "apps.value" }}
{{- $ := index . 0 }}
{{- include "apps-utils.enterScope" (list $ (last .)) }}
{{- include "lib.value" (initial .) }}
{{- include "apps-utils.leaveScope" $ }}
{{- end }}