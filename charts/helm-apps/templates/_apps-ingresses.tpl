{{- define "apps-ingresses" }}
  {{- $ := index . 0 }}
  {{- $RelatedScope := index . 1 }}
    {{- if not (kindIs "invalid" $RelatedScope) }}
  {{- $_ := set $RelatedScope "__GroupVars__" (dict "type" "apps-ingresses" "name" "apps-ingresses") }}
  {{- include "apps-utils.renderApps" (list $ $RelatedScope) }}
  {{- end -}}
{{- end -}}

{{- define "apps-ingresses.render" }}
{{- $ := . }}
{{- with $.CurrentApp }}
{{- $_ := set $ "CurrentIngress" . }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .name | quote }}
  annotations:
    {{- if include "lib.value" (list $ . .class) }}
    kubernetes.io/ingress.class: {{ include "lib.valueQuoted" (list $ . .class) }}{{- end }}
    {{- include "lib.value" (list $ . .annotations) | nindent 4 }}
  labels: {{- include "lib.generateLabels" (list $ . .name) | nindent 4 }}
spec:
  {{- if include "lib.value" (list $ . .ingressClassName) }}
  ingressClassName: {{ include "lib.value" (list $ . .ingressClassName) }}{{- end }}
  {{- if .tls }}
  {{- if include "lib.isTrue" (list $ . .tls.enabled) }}
  tls:
  {{- if (include "lib.value" (list $ . .tls.secret_name)) }}
  - secretName: {{ include "lib.value" (list $ . .tls.secret_name) }}
  {{- else }}
  - secretName: {{ include "lib.value" (list $ . .name) }}
  {{- end }}
  {{- end }}
  {{- end }}
  rules:
  - host: {{ include "lib.valueQuoted" (list $ . .host) }}
    http:
      paths: {{- include "lib.value" (list $ . .paths) | nindent 6 }}
{{- if .tls }}
{{- if include "lib.isTrue" (list $ . .tls.enabled) }}
{{- if not (include "lib.value" (list $ . .tls.secret_name)) }}
---
{{- include "apps-utils.enterScope" (list $ "tls") }}
{{- include "apps-utils.printPath" $ }}
{{- include "apps-components.cerificate" (list $ .) }}
{{- include "apps-utils.leaveScope" $ }}
{{- end -}}

{{- end }}

{{- end }}
{{- end }}
{{- end }}
