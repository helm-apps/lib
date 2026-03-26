{{- define "lib.generateContainerResources" }}
  {{- $ := index . 0 }}
  {{- $relativeScope := index . 1 }}
  {{- $resources := index . 2 }}

  {{- range $resourceGroup, $resourceGroupVals := $resources }}
    {{- $resourceGroup | nindent 0 }}:
      {{- $mcpu := include "lib.value" (list $ . $resourceGroupVals.mcpu (dict "suffix" "m")) }}
      {{- if $mcpu }}{{ cat "cpu:" $mcpu | nindent 2 }}{{ end }}
      {{- $memoryMb := include "lib.value" (list $ . $resourceGroupVals.memoryMb (dict "suffix" "Mi")) }}
      {{- if $memoryMb }}{{ cat "memory:" $memoryMb | nindent 2 }}{{ end }}
      {{- $ESMb := include "lib.value" (list $ . $resourceGroupVals.ephemeralStorageMb (dict "suffix" "Mi")) }}
      {{- if $ESMb }}{{ cat "ephemeral-storage:" $ESMb | nindent 2 }}{{ end }}
  {{- end }}
{{- end }}
