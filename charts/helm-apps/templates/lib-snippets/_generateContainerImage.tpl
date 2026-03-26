{{- define "lib.generateContainerImageQuoted" }}
  {{- $ := index . 0 }}
  {{- $relativeScope := index . 1 }}
  {{- $imageConfig := index . 2 }}

  {{- $imageName := include "lib.value" (list $ . $imageConfig.name) }}
  {{- if include "lib.value" (list $ . $imageConfig.staticTag) }}
    {{- $imageName }}:{{ include "lib.value" (list $ . $imageConfig.staticTag) }}
  {{- else -}}
    {{- index $.Values.global.images $imageName }}
  {{- end }}
{{- end }}
