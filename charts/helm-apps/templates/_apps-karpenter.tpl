{{- define "apps-karpenter" }}
{{-   $ := index . 0 }}
{{-   $RelatedScope := index . 1 }}
{{-   if not (kindIs "invalid" $RelatedScope) }}
{{-   $_ := set $RelatedScope "__GroupVars__" (dict "type" "apps-karpenter-node-pool" "name" "apps-karpenter") }}
{{-   include "apps-utils.renderApps" (list $ $RelatedScope) }}
{{-   end }}
{{- end }}

{{- define "apps-karpenter-node-pool" }}
{{-   $ := index . 0 }}
{{-   $RelatedScope := index . 1 }}
{{-   if not (kindIs "invalid" $RelatedScope) }}
{{-   $_ := set $RelatedScope "__GroupVars__" (dict "type" "apps-karpenter-node-pool" "name" "apps-karpenter-node-pool") }}
{{-   include "apps-utils.renderApps" (list $ $RelatedScope) }}
{{-   end }}
{{- end }}

{{- define "apps-karpenter-node-class" }}
{{-   $ := index . 0 }}
{{-   $RelatedScope := index . 1 }}
{{-   if not (kindIs "invalid" $RelatedScope) }}
{{-   $_ := set $RelatedScope "__GroupVars__" (dict "type" "apps-karpenter-node-class" "name" "apps-karpenter-node-class") }}
{{-   include "apps-utils.renderApps" (list $ $RelatedScope) }}
{{-   end }}
{{- end }}

{{- define "apps-karpenter-node-class.render" }}
{{- $ := . }}
{{- with $.CurrentApp }}
{{- if not (or (include "lib.value" (list $ . .role)) (include "lib.value" (list $ . .instanceProfile))) }}
{{- fail (printf "EC2NodeClass '%s': one of 'role' or 'instanceProfile' is required" $.CurrentApp.name) }}
{{- end }}
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
{{- include "apps-helpers.metadataGenerator" (list $ .) }}
spec:
  {{- $specs := dict }}
  {{- $_ := set $specs "Required" (list "amiSelectorTerms" "subnetSelectorTerms" "securityGroupSelectorTerms") }}
  {{- $_ = set $specs "Strings" (list "role" "instanceProfile" "amiFamily" "instanceStorePolicy") }}
  {{- $_ = set $specs "Numbers" (list "ipPrefixCount") }}
  {{- $_ = set $specs "Bools" (list "detailedMonitoring" "associatePublicIPAddress") }}
  {{- $_ = set $specs "Lists" (list "amiSelectorTerms" "subnetSelectorTerms" "securityGroupSelectorTerms" "blockDeviceMappings" "capacityReservationSelectorTerms") }}
  {{- $_ = set $specs "Maps" (list "tags") }}
  {{- include "apps-utils.generateSpecs" (list $ . $specs) | trim | nindent 2 }}
  {{- with include "lib.value" (list $ . .userData) | trim }}
  userData: |
    {{- . | nindent 4 }}
  {{- end }}
  {{- if .metadataOptions }}
  metadataOptions:
    {{- include "apps-karpenter.metadataOptions" (list $ . .metadataOptions) | trim | nindent 4 }}
  {{- end }}
  {{- if .kubelet }}
  kubelet:
    {{- include "apps-karpenter.kubelet" (list $ . .kubelet) | trim | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "apps-karpenter.metadataOptions" }}
{{- $ := index . 0 }}
{{- $RelatedScope := index . 1 }}
{{- $metadataOptions := index . 2 }}
{{- $specs := dict }}
{{- $_ := set $specs "Strings" (list "httpEndpoint" "httpProtocolIPv6" "httpTokens") }}
{{- $_ = set $specs "Numbers" (list "httpPutResponseHopLimit") }}
{{- include "apps-utils.generateSpecs" (list $ $metadataOptions $specs) | trim }}
{{- end }}

{{- define "apps-karpenter.kubelet" }}
{{- $ := index . 0 }}
{{- $RelatedScope := index . 1 }}
{{- $kubelet := index . 2 }}
{{- $specs := dict }}
{{- $_ := set $specs "Numbers" (list "podsPerCore" "maxPods" "evictionMaxPodGracePeriod" "imageGCHighThresholdPercent" "imageGCLowThresholdPercent") }}
{{- $_ = set $specs "Bools" (list "cpuCFSQuota") }}
{{- $_ = set $specs "Lists" (list "clusterDNS") }}
{{- $_ = set $specs "Maps" (list "systemReserved" "kubeReserved" "evictionHard" "evictionSoft" "evictionSoftGracePeriod") }}
{{- include "apps-utils.generateSpecs" (list $ $kubelet $specs) | trim }}
{{- end }}

{{- define "apps-karpenter-node-pool.render" }}
{{- $ := . }}
{{- with $.CurrentApp }}
apiVersion: karpenter.sh/v1
kind: NodePool
{{- include "apps-helpers.metadataGenerator" (list $ .) }}
spec:
  {{- $specsTop := dict }}
  {{- $_ := set $specsTop "Numbers" (list "weight" "replicas") }}
  {{- include "apps-utils.generateSpecs" (list $ . $specsTop) | trim | nindent 2 }}
  {{- with include "lib.value" (list $ . .limits) | trim }}
  limits: {{ . | nindent 4 }}
  {{- end }}
  template:
    {{- $hasNodeMeta := or (include "lib.value" (list $ . .nodeLabels) | trim) (include "lib.value" (list $ . .nodeAnnotations) | trim) }}
    {{- if $hasNodeMeta }}
    metadata:
      {{- with include "lib.value" (list $ . .nodeLabels) | trim }}
      labels: {{ . | nindent 8 }}
      {{- end }}
      {{- with include "lib.value" (list $ . .nodeAnnotations) | trim }}
      annotations: {{ . | nindent 8 }}
      {{- end }}
    {{- end }}
    spec:
      {{- if not (hasKey . "nodeClassRef") }}
      {{- fail (printf "NodePool '%s': nodeClassRef is required" $.CurrentApp.name) }}
      {{- end }}
      nodeClassRef:
        group: {{ include "lib.value" (list $ . (.nodeClassRef.group | default "karpenter.k8s.aws")) | quote }}
        kind: {{ include "lib.value" (list $ . (.nodeClassRef.kind | default "EC2NodeClass")) | quote }}
        name: {{ include "apps-utils.requiredValue" (list $ .nodeClassRef "name") | quote }}
      {{- $specsSpec := dict }}
      {{- $_ = set $specsSpec "Lists" (list "requirements" "taints" "startupTaints") }}
      {{- $_ = set $specsSpec "Strings" (list "expireAfter" "terminationGracePeriod") }}
      {{- include "apps-utils.generateSpecs" (list $ . $specsSpec) | trim | nindent 6 }}
  {{- if .disruption }}
  disruption:
    {{- include "apps-karpenter.disruption" (list $ . .disruption) | trim | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "apps-karpenter.disruption" }}
{{- $ := index . 0 }}
{{- $RelatedScope := index . 1 }}
{{- $disruption := index . 2 }}
{{- $specs := dict }}
{{- $_ := set $specs "Strings" (list "consolidationPolicy" "consolidateAfter") }}
{{- $_ = set $specs "Lists" (list "budgets") }}
{{- include "apps-utils.generateSpecs" (list $ $disruption $specs) | trim }}
{{- end }}
