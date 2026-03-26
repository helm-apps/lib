{{- define "apps-stateful" }}
  {{- $ := index . 0 }}
  {{- $RelatedScope := index . 1 }}
    {{- if not (kindIs "invalid" $RelatedScope) }}

  {{- $_ := set $RelatedScope "__GroupVars__" (dict "type" "apps-stateful" "name" "apps-stateful") }}
  {{- include "apps-utils.renderApps" (list $ $RelatedScope) }}
{{- end -}}
{{- end -}}

{{- define "apps-stateful.render" }}
{{- $ := . }}
{{- with $.CurrentApp }}
{{- if not .containers }}
{{- fail (printf "'%s' is enabled in apps-stateful but has no containers configured" $.CurrentApp.name) }}
{{- end }}
{{/* Defaults values */}}
{{- if .service }}
{{- if include "lib.isTrue" (list $ . .service.enabled) }}
{{- if not .service.name }}
{{- $_ := set .service "name" .name }}
{{- end }}
{{- end }}
{{- end }}
{{/* Defaults values end */}}
{{- $serviceAccount := include "apps-system.serviceAccount" $ }}
apiVersion: apps/v1
kind: StatefulSet
{{ $_ := set . "__annotations__" dict }}
{{- if .reloader }}
{{- $_ := set .__annotations__ "pod-reloader.deckhouse.io/auto" "true" }}
{{- else }}
{{- $_ := set . "__annotations__" (include "apps-components.generate-config-checksum" (list $ .) | fromYaml) }}
{{-  end }}
{{- include "apps-helpers.metadataGenerator" (list $ .) }}
spec:
  {{- /* https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.32/#statefulset-v1-apps */ -}}
  {{- $specs := dict }}
  {{- $_ = set $specs "Maps" (list "apps-helpers.podTemplate" "apps-specs.selector" "persistentVolumeClaimRetentionPolicy" "updateStrategy") }}
  {{- $_ = set $specs "Numbers" (list "replicas" "minReadySeconds" "revisionHistoryLimit" "progressDeadlineSeconds") }}
  {{- $_ = set $specs "Strings" (list "apps-specs.serviceName" "podManagementPolicy") }}
  {{- $_ = set $specs "Lists" (list "apps-specs.volumeClaimTemplates") }}
  {{- include "apps-utils.generateSpecs" (list $ . $specs) | nindent 2 }}
  {{- $_ = unset . "__annotations__" -}}

{{- include "apps-components.generateConfigMapsAndSecrets" $ -}}

{{- include "apps-components.service" (list $ . .service) -}}

{{- include "apps-components.podDisruptionBudget" (list $ . .podDisruptionBudget) -}}

{{- include "apps-components.verticalPodAutoscaler" (list $ . .verticalPodAutoscaler "StatefulSet") -}}

{{ $serviceAccount -}}

{{- end }}
{{- end }}