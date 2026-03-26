{{- define "apps-components.verticalPodAutoscaler" }}
{{-   $ := index . 0 }}
{{-   $RelatedScope := index . 1 }}
{{-   $verticalPodAutoscaler := index . 2 }}
{{-   $kind := index . 3 }}
{{-   include "apps-utils.enterScope" (list $ "verticalPodAutoscaler") }}
{{-   if $verticalPodAutoscaler }}
{{-     if include "lib.isTrue" (list $ . $verticalPodAutoscaler.enabled) }}
---
{{- include "apps-utils.printPath" $ }}
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
{{- include "apps-helpers.metadataGenerator" (list $ $verticalPodAutoscaler ) }}
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: {{ $kind }}
    name: {{ $.CurrentApp.name | quote }}
  updatePolicy:
    updateMode: {{ include "lib.valueQuoted" (list $ . $verticalPodAutoscaler.updateMode) | default (print "Off" | quote )}}
{{-       if include "lib.value" (list $ . $verticalPodAutoscaler.resourcePolicy) }}
  resourcePolicy: {{- include "lib.value" (list $ . $verticalPodAutoscaler.resourcePolicy) | trim | nindent 4 }}
{{-       else }}
  resourcePolicy: {}
{{-       end }}
{{-     end }}
{{-   end }}
{{-   include "apps-utils.leaveScope" $ }}
{{- end }}

{{- define "apps-components.cerificate" }}
{{-   $ := index . 0 }}
{{-   $RelatedScope := index . 1 }}
{{- with $RelatedScope }}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ include "lib.value" (list $ . .name) }}
spec:
  secretName: {{ include "lib.value" (list $ . .name) }}
  issuerRef:
    kind: ClusterIssuer
    name: {{ include "lib.valueQuoted" (list $ . .clusterIssuer) | default "letsencrypt" }}
  dnsNames:
  {{- with .host }}
  - {{ include "lib.valueQuoted" (list $ $RelatedScope .) }}
  {{- end }}
  {{- with .hosts }}
  {{- include "lib.value" (list $ $RelatedScope .) | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "apps-components.podDisruptionBudget" }}
{{-   $ := index . 0 }}
{{-   $RelatedScope := index . 1 }}
{{-   $podDisruptionBudget := index . 2 }}
{{-   include "apps-utils.enterScope" (list $ "podDisruptionBudget") }}

{{-   with $podDisruptionBudget }}
{{-     if include "lib.isTrue" (list $ . .enabled) }}
---
{{- include "apps-utils.printPath" $ }}
{{-       if semverCompare ">=1.21.0-0" $.Capabilities.KubeVersion.GitVersion }}
apiVersion: policy/v1
{{-       else }}
apiVersion: policy/v1beta1
{{-       end }}
kind: PodDisruptionBudget
{{- include "apps-helpers.metadataGenerator" (list $ $podDisruptionBudget) }}
spec:
  selector:
    matchLabels:
{{-         if empty (include "lib.value" (list $ . $.CurrentApp.selector)) }}
{{-            include "lib.generateSelectorLabels" (list $ . $.CurrentApp.name) | trim | nindent 6 }}
{{- else }}
{{-            $.CurrentApp.selector | trim | nindent 6 }}
{{- end }}
{{- with include "lib.value" (list $ . .maxUnavailable) }}
  maxUnavailable: {{ . }}
{{- end }}
{{- with include "lib.value" (list $ . .minAvailable) }}
  minAvailable: {{ . }}
{{- end }}
{{-     end }}
{{-   end }}
{{-   include "apps-utils.leaveScope" $ }}
{{- end }}

{{- define "apps-components.service" }}
{{-   $ := index . 0 }}
{{-   $RelatedScope := index . 1 }}
{{-   $service := index . 2 }}
{{-   if $service }}
{{-     if include "lib.isTrue" (list $ . $service.enabled) }}
{{-       if include "lib.value" (list $ . $service.ports) }}
{{-         include "apps-utils.enterScope" (list $ "service") }}
---
{{-         include "apps-utils.printPath" $ }}
{{-         if empty (include "lib.value" (list $ . $service.selector)) }}
{{-           $_ := set $service "selector" (include "lib.generateSelectorLabels" (list $ . $.CurrentApp.name) | trim) }}
{{-         end }}
{{-         if include "lib.isTrue" (list $ . $service.headless) }}
{{-           $_ := set $service "clusterIP" "None" }}
{{-         end }}
{{-         include "apps-components._service" (list $ $service) }}
{{-         include "apps-utils.leaveScope" $ }}
{{-       end }}
{{-     end }}
{{-   end }}
{{- end }}

{{- define "apps-components._service" }}
{{-   $ := index . 0 }}
{{-   $RelatedScope := index . 1 }}
apiVersion: v1
kind: Service
{{- include "apps-helpers.metadataGenerator" (list $ $RelatedScope) }}
spec:
  {{- /* https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.32/#service-v1-core */ -}}
  {{- $specs := dict }}
  {{- $_ := set $specs "Bools" (list "publishNotReadyAddresses" "allocateLoadBalancerNodePorts") }}
  {{- $_ = set $specs "Lists" (list "clusterIPs" "externalIPs" "ipFamilies" "loadBalancerSourceRanges" "ports") }}
  {{- $_ = set $specs "Strings" (list "externalName" "externalTrafficPolicy" "internalTrafficPolicy" "ipFamilyPolicy" "loadBalancerClass" "loadBalancerIP" "sessionAffinity" "type" "clusterIP") }}
  {{- $_ = set $specs "Numbers" (list "healthCheckNodePort") }}
  {{- $_ = set $specs "Maps" (list "sessionAffinityConfig" "selector") }}
  {{- include "apps-utils.generateSpecs" (list $ $RelatedScope $specs) | nindent 2 }}
{{- end }}


{{- define "apps-components.horizontalPodAutoscaler" }}
{{-   $ := index . 0 }}
{{-   $RelatedScope := index . 1 }}
{{-   include "apps-utils.enterScope" (list $ "horizontalPodAutoscaler") }}
{{-   $kind := index . 2 }}
{{-   with $RelatedScope }}
{{-     if $.CurrentApp.horizontalPodAutoscaler }}
{{-       if include "lib.isTrue" (list $ . $.CurrentApp.horizontalPodAutoscaler.enabled) }}
---
{{- include "apps-utils.printPath" $ }}
{{- if $.Capabilities.APIVersions.Has "autoscaling/v2" }}
apiVersion: autoscaling/v2
{{- else }}
apiVersion: autoscaling/v2beta2
{{- end }}
kind: HorizontalPodAutoscaler
{{- include "apps-helpers.metadataGenerator" (list $ $.CurrentApp.horizontalPodAutoscaler ) }}
spec:
  minReplicas: {{ include "lib.value" (list $ . $.CurrentApp.horizontalPodAutoscaler.minReplicas) }}
  maxReplicas: {{ include "lib.value" (list $ . $.CurrentApp.horizontalPodAutoscaler.maxReplicas) }}
  behavior: {{- include "lib.value" (list $ . $.CurrentApp.horizontalPodAutoscaler.behavior) | trim | nindent 4 }}
  scaleTargetRef:
    apiVersion: apps/v1
    kind: {{ $kind }}
    name: {{ $.CurrentApp.name | quote }}
  metrics:
{{-         with required (printf "You need a valid entry in horizontalPodAutoscaler.metrics on %s app" $.CurrentApp.name) $.CurrentApp.horizontalPodAutoscaler.metrics }}
{{-           if kindIs "string" . }}
{{-             print (include "lib.value" (list $ . .)) | nindent 2 }}
{{-           else if kindIs "map" . }}
{{-             include "apps-helpers.generateHPAMetrics" (list $ $RelatedScope) | trim | nindent 2 }}
{{-           end }}
{{-         end }}
{{-       end }}
{{-     end }}
{{-   end }}
{{-   include "apps-utils.leaveScope" $ }}
{{- end }}

{{- define "apps-components.generateConfigMapsAndSecrets" }}
{{-   $ := . }}
{{- /* Loop through containers to generate ConfigMaps and Secrets */ -}}
{{-   range $_, $containersType := list "initContainers" "containers" }}
{{-   include "apps-utils.enterScope" (list $ $containersType) }}
{{-     range $_containerName, $_container := index $.CurrentApp $containersType }}
{{-   include "apps-utils.enterScope" (list $ $_containerName) }}
{{-       if include "lib.isTrue" (list $ . .enabled) }}
{{-         $_ := set . "name" $_containerName }}
{{-         $_ = set $ "CurrentContainer" $_container }}
{{- /* ConfigMaps created by "configFiles:" option */ -}}
{{-   include "apps-utils.enterScope" (list $ "configFiles") }}
{{-         range $configFileName, $configFile := .configFiles }}
{{-           if include "lib.value" (list $ . .content) }}
{{-           include "apps-utils.enterScope" (list $ $configFileName) }}
---
{{- include "apps-utils.printPath" $ }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ print "config-" $containersType "-" $.CurrentApp.name "-" $.CurrentContainer.name "-" $configFileName | include "lib.formatStringAsDNSLabel" | quote }}
  {{- with  include "apps-helpers.generateAnnotations" (list $ .) | trim }}
  {{- . | nindent 2 }}
  {{- end }}
  labels: {{ include "lib.generateLabels" (list $ . $.CurrentApp.name) | trim | nindent 4 }}
data:
  {{ $configFileName | quote }}: | {{ include "lib.value" (list $ . .content) | trim | nindent 4 }}
{{-           include "apps-utils.leaveScope" $ }}
{{-           end }}
{{-         end }}
{{-           include "apps-utils.leaveScope" $ }}
{{- /* ConfigMaps created by "configFilesYAML:" option */ -}}
{{-   include "apps-utils.enterScope" (list $ "configFilesYAML") }}
{{-         range $configFileName, $configFile := .configFilesYAML }}
{{-           if kindIs "map" .content }}
{{-           include "apps-utils.enterScope" (list $ $configFileName) }}
---
{{- include "apps-utils.printPath" $ }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ print "config-yaml-" $containersType "-" $.CurrentApp.name "-" $.CurrentContainer.name "-" $configFileName | include "lib.formatStringAsDNSLabel" | quote }}
  {{- with  include "apps-helpers.generateAnnotations" (list $ .) | trim }}
  {{- . | nindent 2 }}
  {{- end }}
  labels: {{ include "lib.generateLabels" (list $ . $.CurrentApp.name) | trim | nindent 4 }}
data:
{{- $_ := set $ "CurrentConfigYAML" (dict "local" . "content" .) }}
{{- include "apps-helpers.generateConfigYAML" $ }}
  {{ $configFileName | quote }}: | {{ toYaml .content | trim | nindent 4 }}
{{-           include "apps-utils.leaveScope" $ }}
{{-           end }}
{{-         end }}
{{-           include "apps-utils.leaveScope" $ }}
{{- /* Secrets created by "secretConfigFiles:" option */ -}}
{{-         range $secretConfigFileName, $secretConfigFile := .secretConfigFiles }}
{{-           if include "lib.value" (list $ . .content) }}
{{-           include "apps-utils.enterScope" (list $ $secretConfigFileName) }}
---
{{- include "apps-utils.printPath" $ }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ print "config-" $containersType "-" $.CurrentApp.name "-" $.CurrentContainer.name "-" $secretConfigFileName | include "lib.formatStringAsDNSLabel" | quote }}
  {{- with  include "apps-helpers.generateAnnotations" (list $ .) | trim }}
  {{- . | nindent 2 }}
  {{- end }}
  labels: {{ include "lib.generateLabels" (list $ . $.CurrentApp.name) | trim | nindent 4 }}
type: Opaque
data:
  {{ $secretConfigFileName | quote }}: {{ include "lib.value" (list $ . .content) | b64enc | quote }}
{{-           include "apps-utils.leaveScope" $ }}
{{-           end }}
{{-         end }}
{{- /* Secret created by "secretEnvVars:" option */ -}}
{{-         if include "lib.generateSecretEnvVars" (list $ . .secretEnvVars) }}
{{-           include "apps-utils.enterScope" (list $ "secretEnvVars") }}
---
{{- include "apps-utils.printPath" $ }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ print "envs-" $containersType "-" $.CurrentApp.name "-" .name | include "lib.formatStringAsDNSLabel" | quote }}
  {{- with  include "apps-helpers.generateAnnotations" (list $ .) | trim }}
  {{- . | nindent 2 }}
  {{- end }}
  labels: {{ include "lib.generateLabels" (list $ . $.CurrentApp.name) | trim | nindent 4 }}
type: Opaque
data: {{ include "lib.generateSecretEnvVars" (list $ . .secretEnvVars) | trim | nindent 2 }}
{{-   include "apps-utils.leaveScope" $ }}
{{-         end }}
{{-       end }}
{{-   include "apps-utils.leaveScope" $ }}
{{-     end }}
{{-   include "apps-utils.leaveScope" $ }}
{{-   end }}
{{- end }}

{{- define "apps-components.generate-config-checksum" }}
{{-   $ := index . 0 }}
{{-   $RelatedScope := index . 1 }}
  {{- /* Loop through containers to generate Pod volumes */ -}}
{{-   $allConfigMaps := "" }}
{{-   range $_, $containersType := list "initContainers" "containers" }}
{{-     range $_containerName, $_container := index $.CurrentApp $containersType }}
{{-         $_ := set $ "CurrentContainer" . }}
{{- if hasKey . "enabled" }}
{{-       if include "lib.isTrue" (list $ . .enabled) }}
{{-           $allConfigMaps = print $allConfigMaps (include "apps-components._generate-config-checksum" $) }}
{{-       end }}
{{- else }}
{{-           $allConfigMaps = print $allConfigMaps (include "apps-components._generate-config-checksum" $) }}
{{- end }}
{{-   end }}

{{-   end }}
{{-   printf "checksum/config: '%s'" ($allConfigMaps | sha256sum) }}
{{- end }}

{{- define "apps-components._generate-config-checksum" }}
{{- $ := . }}
{{- with $.CurrentApp }}
{{-         range $_, $configFile := $.CurrentContainer.configFiles }}
{{-           print (include "lib.value" (list $ . $configFile.content)) }}
{{-         end }}
{{-         range $_, $configFile :=  $.CurrentContainer.secretConfigFiles }}
{{-           print (include "lib.value" (list $ . $configFile.content)) }}
{{-         end }}
{{-         range $_, $configFile :=  $.CurrentContainer.configFilesYAML }}
{{- $_ := set $ "CurrentConfigYAML" (dict "local" $.CurrentApp "content" $configFile.content) }}
{{- include "apps-helpers.generateConfigYAML" $ }}
{{- $configFile.content | toYaml }}
{{-         end }}
{{- end }}
{{- end }}
