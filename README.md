# helm-apps

A Helm library chart that generates complete Kubernetes manifests from a concise `values.yaml` configuration using a macro system.

## Features

- **Simplified manifest structure** — declare applications with a fraction of the YAML required by raw Kubernetes resources
- **Config reuse via `_include`** — merge reusable configuration blocks into any resource definition, eliminating duplication across environments and apps
- **Per-environment overrides** — any field can carry a `_default` value plus environment-specific overrides resolved at render time via `global.env`
- **Go template interpolation** — field values support Go template expressions with access to `$.Values`, `$.Release`, and `$.CurrentApp`
- **Comprehensive resource generation** — Deployments, StatefulSets, CronJobs, Jobs, ConfigMaps, Secrets, Services, Ingresses, Certificates, PVCs, PodDisruptionBudgets, HorizontalPodAutoscalers, VerticalPodAutoscalers, LimitRanges, and Karpenter NodePools/EC2NodeClasses

## Quick Start

### 1. Add the repository and declare the dependency

```bash
helm repo add helm-apps https://helm-apps.github.io/lib
helm dependency update .helm
```

```yaml
# .helm/Chart.yaml
apiVersion: v2
name: myapp
version: 1.0.0
dependencies:
- name: helm-apps
  version: "~1"
  repository: "@helm-apps"
```

### 2. Initialize the library

Create `.helm/templates/init-helm-apps-library.yaml` with:

```yaml
{{- /* Initialize the helm-apps library */}}
{{- include "apps-utils.init-library" $ }}
```

### 3. Declare your applications in `values.yaml`

All resource declarations live under top-level keys such as `apps-stateless`, `apps-ingresses`, etc. See the [example below](#example-nginx-deployment--ingress) and the [resource type table](#available-resource-types) for the full list.

## Core Concepts

### `lib.value` and per-environment overrides

Every field in `values.yaml` is processed by the `lib.value` function. This means any scalar field can be written in one of three forms:

```yaml
# Plain value — used for all environments
replicas: 2

# Explicit default — equivalent to the plain form
replicas:
  _default: 2

# Default with environment-specific override
replicas:
  _default: 2
  prod: 5
```

The active environment is set at render time by `global.env` (e.g. `--set "global.env=prod"`). If `global.env` matches a key, that value is used; otherwise `_default` is used.

Environment keys support regular expressions:

```yaml
priorityClassName:
  _default: "low-priority"
  prod: "production-high"
  "staging|review": "staging-medium"
```

### Go template interpolation

Any scalar field value that contains `{{` is rendered as a Go template:

```yaml
global:
  ci_url: example.com

apps-stateless:
  frontend:
    containers:
      nginx:
        configFiles:
          default.conf:
            mountPath: /etc/nginx/conf.d/default.conf
            content: |
              server_name {{ $.Values.global.ci_url }};
```

Available template variables include `$.Values`, `$.Release.Namespace`, `$.Release.Name`, and `$.CurrentApp.name` (the key under the `apps-*` section).

### Config reuse with `_include`

Reusable configuration blocks are defined under `global._includes` and referenced anywhere with `_include: ["block-name"]`. Keys defined alongside `_include` override keys from the included block:

```yaml
global:
  _includes:
    my-defaults:
      replicas: 2
      imagePullSecrets: |
        - name: registrysecret

apps-stateless:
  frontend:
    _include: ["my-defaults"]
    replicas: 5          # overrides the included value of 2
```

Includes can be chained — a block may itself contain an `_include`.

### Raw YAML strings for lists and maps

Fields that accept lists or maps (such as `ports`, `volumes`, `affinity`, `strategy`) must be written as YAML block scalars using `|`. The string is inserted verbatim into the generated manifest without further parsing:

```yaml
# Correct
ports: |
  - name: http
    containerPort: 80

# Incorrect — will not be processed correctly
ports:
  - name: http
    containerPort: 80
```

JSON-style inline lists and maps are not supported for these fields.

## Example: Nginx Deployment + Ingress

```yaml
global:
  ci_url: example.com

  _includes:
    _include_from_file: helm-apps-defaults.yaml

apps-stateless:
  nginx:
    _include: ["apps-stateless-defaultApp"]
    replicas: 1
    containers:
      nginx:
        image:
          name: nginx
          staticTag: "latest"
        ports: |
          - name: http
            containerPort: 80
        configFiles:
          default.conf:
            mountPath: /etc/nginx/templates/default.conf.template
            content: |
              server {
                listen         80 default_server;
                server_name    {{ $.Values.global.ci_url }};
                root           /var/www/{{ $.Values.global.ci_url }};
                index          index.html;
                location / {
                  proxy_set_header Authorization "Bearer ${SECRET_TOKEN}";
                  proxy_pass https://backend:3000;
                }
              }
        secretEnvVars:
          SECRET_TOKEN: "my-secret-token"
    service:
      enabled: true
      ports: |
        - name: http
          port: 80

apps-ingresses:
  nginx:
    _include: ["apps-ingresses-defaultIngress"]
    host: '{{ $.Values.global.ci_url }}'
    paths: |
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
    tls:
      enabled: true
```

<details>
<summary>Generated Kubernetes manifests</summary>

```yaml
# Helm Apps Library: apps-stateless.nginx.podDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: "nginx"
  labels:
    app: "nginx"
    chart: "myapp"
    repo: ""
spec:
  selector:
    matchLabels:
      app: "nginx"
  maxUnavailable: "15%"
---
# Helm Apps Library: apps-stateless.nginx.containers.nginx.secretEnvVars
apiVersion: v1
kind: Secret
metadata:
  name: "envs-containers-nginx-nginx"
  labels:
    app: "nginx"
    chart: "myapp"
    repo: ""
type: Opaque
data:
  "SECRET_TOKEN": "bXktc2VjcmV0LXRva2Vu"
---
# Helm Apps Library: apps-stateless.nginx.containers.nginx.configFiles.default.conf
apiVersion: v1
kind: ConfigMap
metadata:
  name: "config-containers-nginx-nginx-default-conf"
  labels:
    app: "nginx"
    chart: "myapp"
    repo: ""
data:
  "default.conf": |
    server {
      listen         80 default_server;
      server_name    example.com;
      root           /var/www/example.com;
      index          index.html;
      location / {
        proxy_set_header Authorization "Bearer ${SECRET_TOKEN}";
        proxy_pass https://backend:3000;
      }
    }
---
# Helm Apps Library: apps-stateless.nginx.service
apiVersion: v1
kind: Service
metadata:
  name: "nginx"
  labels:
    app: "nginx"
    chart: "myapp"
    repo: ""
spec:
  selector:
    app: "nginx"
  ports:
    - name: http
      port: 80
---
# Helm Apps Library: apps-stateless.nginx
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "nginx"
  annotations:
    checksum/config: "a1b2c3d4e5f6..."
  labels:
    app: "nginx"
    chart: "myapp"
    repo: ""
spec:
  replicas: 1
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: "nginx"
  strategy:
    rollingUpdate:
      maxSurge: 20%
      maxUnavailable: 50%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: "nginx"
        chart: "myapp"
        repo: ""
      annotations:
        checksum/config: "a1b2c3d4e5f6..."
    spec:
      imagePullSecrets:
        - name: registrysecret
      containers:
        - name: "nginx"
          image: "nginx:latest"
          envFrom:
            - secretRef:
                name: "envs-containers-nginx-nginx"
          ports:
            - name: http
              containerPort: 80
          volumeMounts:
            - name: "config-containers-nginx-nginx-default-conf"
              subPath: "default.conf"
              mountPath: "/etc/nginx/templates/default.conf.template"
      volumes:
        - name: "config-containers-nginx-nginx-default-conf"
          configMap:
            name: "config-containers-nginx-nginx-default-conf"
---
# Helm Apps Library: apps-ingresses.nginx
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: "nginx"
  annotations:
    kubernetes.io/ingress.class: "nginx"
  labels:
    app: "nginx"
    chart: "myapp"
    repo: ""
spec:
  tls:
    - secretName: nginx
  rules:
    - host: "example.com"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx
                port:
                  number: 80
---
# Helm Apps Library: apps-ingresses.nginx.tls
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nginx
  labels:
    app: "nginx"
    chart: "myapp"
    repo: ""
spec:
  secretName: nginx
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt
  dnsNames:
    - "example.com"
---
# Helm Apps Library: apps-stateless.nginx.verticalPodAutoscaler
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: "nginx"
  labels:
    app: "nginx"
    chart: "myapp"
    repo: ""
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: "nginx"
  updatePolicy:
    updateMode: "Off"
  resourcePolicy: {}
```

</details>

## Available Resource Types

| `values.yaml` key | Kubernetes resource(s) generated |
|---|---|
| `apps-stateless` | Deployment, Service, PodDisruptionBudget, HorizontalPodAutoscaler, VerticalPodAutoscaler, ConfigMaps (configFiles), Secrets (secretEnvVars / secretConfigFiles) |
| `apps-stateful` | StatefulSet, Service (headless), PodDisruptionBudget, VerticalPodAutoscaler, ConfigMaps, Secrets |
| `apps-cronjobs` | CronJob, VerticalPodAutoscaler, ConfigMaps, Secrets |
| `apps-jobs` | Job, VerticalPodAutoscaler, ConfigMaps, Secrets |
| `apps-configmaps` | ConfigMap |
| `apps-secrets` | Secret |
| `apps-ingresses` | Ingress, Certificate (cert-manager, when `tls.enabled: true`) |
| `apps-certificates` | Certificate (cert-manager) |
| `apps-services` | Service |
| `apps-pvcs` | PersistentVolumeClaim |
| `apps-limit-range` | LimitRange |
| `apps-karpenter-node-pool` | NodePool (karpenter.sh/v1) |
| `apps-karpenter-node-class` | EC2NodeClass (karpenter.k8s.aws/v1) |

## Defaults and Includes

### `global._includes` and `helm-apps-defaults.yaml`

Shared defaults are typically declared in a separate file (conventionally `.helm/helm-apps-defaults.yaml`) and loaded via:

```yaml
global:
  _includes:
    _include_from_file: helm-apps-defaults.yaml
```

This file defines named include blocks such as `apps-stateless-defaultApp`, `apps-cronjobs-defaultCronJob`, etc. that set sensible defaults for each resource type. Any project-level `values.yaml` entry that carries `_include: ["apps-stateless-defaultApp"]` will inherit all of those defaults and can selectively override individual keys.

### `_include_from_file` for nested includes

A named include block can itself load from a file:

```yaml
global:
  _includes:
    my-block:
      _include_from_file: config/my-block.yaml
```

This is useful for splitting large include blocks into separate files that can be maintained independently.

## Rendering for Development

To render templates locally against a specific environment:

```bash
helm template myapp .helm --namespace myns --set "global.env=prod"
```

Omit `--set "global.env=..."` (or set it to an empty string) to use `_default` values for all fields.
