# helm-apps Usage Guide

This guide covers the features of the helm-apps library chart in detail. For initial setup see the [README](../README.md).

---

## 1. Per-Environment Overrides

Any scalar field in `values.yaml` can be written in one of three forms. The active environment is the value of `global.env`, which is passed at render time (e.g. `--set "global.env=prod"`).

### Flat value — the same for all environments

```yaml
revisionHistoryLimit: 3
```

### Explicit `_default` — functionally identical to the flat form

```yaml
revisionHistoryLimit:
  _default: 3
```

### `_default` with one or more environment-specific overrides

```yaml
terminationGracePeriodSeconds:
  _default: 30
  prod: 60

priorityClassName:
  _default: "low-priority"
  prod: "production-high"
  staging: "staging-medium"
```

When `global.env` matches a key exactly, that value is used. When there is no match, `_default` is used. If `_default` is absent and there is no match, the field is treated as empty (and usually omitted from the generated manifest).

Environment keys are matched as regular expressions, so the following is valid:

```yaml
priorityClassName:
  _default: "low-priority"
  "prod|production": "production-high"
```

### Setting `global.env`

Pass `global.env` at render time:

```bash
helm template myapp .helm --namespace myns --set "global.env=prod"
```

Or define a default in `values.yaml`:

```yaml
global:
  env: ""
```

---

## 2. Go Template Interpolation

Any scalar field value that contains `{{` is rendered as a Go template. The full Helm template context is available, including:

| Variable | Description |
|---|---|
| `$.Values` | All chart values |
| `$.Release.Namespace` | Namespace passed to `helm template` / `helm install` |
| `$.Release.Name` | Release name |
| `$.CurrentApp.name` | The key of the current resource under its `apps-*` section |

### Examples

```yaml
global:
  ci_url: example.com
  domain_suffix: ".internal"

apps-stateless:
  backend:
    containers:
      app:
        # Compose the image URL from values
        image:
          name: "{{ $.Values.global.images.backend }}"

        # Use release namespace in a config file
        configFiles:
          app.conf:
            mountPath: /etc/app/app.conf
            content: |
              namespace = {{ $.Release.Namespace }}
              host = {{ $.Values.global.ci_url }}

    service:
      # Build the service name from the app key
      name: "{{ $.CurrentApp.name }}-svc"
```

```yaml
apps-stateful:
  postgres:
    # Use the app name automatically for the headless service
    service:
      enabled: true
      name: "{{ $.CurrentApp.name }}"
      headless: true
```

Go template expressions are evaluated after `_include` merging and environment resolution, so they have access to the fully resolved values.

---

## 3. Enabling and Disabling Components

Every top-level resource entry and most sub-components support an `enabled` flag. When `enabled` is `false` (or resolves to `false` for the current environment), the resource and all its child resources are skipped.

```yaml
apps-stateless:
  frontend:
    enabled: true          # the entire Deployment + its sub-resources

    service:
      enabled: true        # opt in to Service generation

    horizontalPodAutoscaler:
      enabled: false       # suppress HPA even if defined in an _include block

    verticalPodAutoscaler:
      enabled: true
      updateMode: "Off"
```

This is most useful when combined with per-environment overrides to selectively activate resources in specific environments:

```yaml
apps-stateless:
  debug-tool:
    enabled:
      _default: false
      staging: true        # only render this Deployment on staging
```

---

## 4. Multiple Resources of the Same Type

Each `apps-*` key is a map. Every key inside it declares one independent resource. There is no limit on the number of entries.

```yaml
apps-stateless:
  frontend:
    _include: ["apps-stateless-defaultApp"]
    replicas: 2
    containers:
      nginx:
        image:
          name: nginx
          staticTag: "1.27"

  backend:
    _include: ["apps-stateless-defaultApp"]
    replicas: 3
    containers:
      app:
        image:
          name: myregistry.example.com/myapp/backend
          staticTag: "v1.0.0"

apps-cronjobs:
  nightly-report:
    _include: ["apps-cronjobs-defaultCronJob"]
    schedule: "0 2 * * *"
    containers:
      reporter:
        image:
          name: myregistry.example.com/myapp/reporter
          staticTag: "v1.0.0"

  hourly-sync:
    _include: ["apps-cronjobs-defaultCronJob"]
    schedule: "0 * * * *"
    containers:
      syncer:
        image:
          name: myregistry.example.com/myapp/syncer
          staticTag: "v1.0.0"
```

Each entry gets its own set of generated manifests (Deployment, Service, PodDisruptionBudget, etc.) independently named after the map key.

---

## 5. Raw YAML Strings

Fields that map to Kubernetes list or map structures (such as `ports`, `volumes`, `affinity`, `tolerations`, `strategy`, `command`, `args`, `envFrom`, `annotations`, `labels`) must be written as YAML block scalars using the `|` operator. The string is inserted verbatim into the generated manifest.

This is necessary because Helm merges `values.yaml` entries as maps, which would lose ordering and structure for lists. The `|` form preserves the exact YAML and is passed through without transformation.

### Correct usage

```yaml
# List field — must use |
ports: |
  - name: http
    containerPort: 80
  - name: metrics
    containerPort: 9090

# Map field — must use |
affinity: |
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 10
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            app: frontend

# Strategy (map) — must use |
strategy: |
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 25%
    maxUnavailable: 0

# Command (list) — must use |
command: |
  - /bin/sh
  - -c
  - echo hello
```

### Incorrect usage

```yaml
# Wrong — native YAML list
ports:
  - name: http
    containerPort: 80

# Wrong — JSON-style list in block scalar
ports: |
  [{"name": "http", "containerPort": 80}]

# Wrong — native YAML map
affinity:
  podAntiAffinity: ...
```

Go template expressions are fully supported inside raw YAML strings:

```yaml
affinity: |
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 10
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels: {{ include "lib.generateSelectorLabels" (list $ . .name) | nindent 12 }}
```

---

## 6. Config Reuse with `_include`

`_include` is a more powerful alternative to YAML anchors. It merges a named block from `global._includes` into the current resource definition. Keys defined alongside `_include` override keys from the included block.

### Defining include blocks

Include blocks live under `global._includes` in any values file (commonly in `helm-apps-defaults.yaml`):

```yaml
# helm-apps-defaults.yaml
apps-defaults:
  enabled: false

apps-default-library-app:
  _include: ["apps-defaults"]
  imagePullSecrets: |
    - name: registrysecret

apps-stateless-defaultApp:
  _include: ["apps-default-library-app"]
  revisionHistoryLimit: 3
  strategy:
    _default: |
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 20%
        maxUnavailable: 50%
    prod: |
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 20%
        maxUnavailable: 25%
  podDisruptionBudget:
    enabled: true
    maxUnavailable: "15%"
  verticalPodAutoscaler:
    enabled: true
    updateMode: "Off"
  service:
    enabled: false
    name: "{{ $.CurrentApp.name }}"
```

### Referencing an include block

```yaml
apps-stateless:
  frontend:
    _include: ["apps-stateless-defaultApp"]
    replicas: 2                  # adds a key not in the include block
    service:
      enabled: true              # overrides service.enabled from the include block
```

### Chaining includes

An include block can itself use `_include`:

```yaml
global:
  _includes:
    base-app:
      imagePullSecrets: |
        - name: registrysecret

    production-app:
      _include: ["base-app"]
      priorityClassName: "production-high"
      replicas:
        _default: 2
        prod: 5
```

### Using multiple includes

Pass a list of block names. They are merged left-to-right; later blocks override earlier ones:

```yaml
apps-stateless:
  api:
    _include: ["apps-stateless-defaultApp", "my-monitoring-defaults"]
```

---

## 7. `_include_from_file`

A named block inside `global._includes` can load its content from a separate YAML file instead of being defined inline. The path is relative to the chart root (`.helm/`).

```yaml
global:
  _includes:
    _include_from_file: helm-apps-defaults.yaml
```

When used as the value of `_include_from_file` directly under `global._includes`, all top-level keys from the file are merged into `global._includes`.

A named block can also point to a file:

```yaml
global:
  _includes:
    _include_from_file: helm-apps-defaults.yaml
    team-overrides:
      _include_from_file: config/team-overrides.yaml
```

The file must contain a valid YAML map. Its keys become the keys of the named block.

---

## 8. Defaults File (`helm-apps-defaults.yaml`)

The conventional pattern is to keep all shared defaults in a file named `.helm/helm-apps-defaults.yaml`, which is loaded into `global._includes` via `_include_from_file`. This file defines one include block per resource type, named by convention:

| Block name | Intended for |
|---|---|
| `apps-stateless-defaultApp` | `apps-stateless` entries |
| `apps-stateful-defaultApp` | `apps-stateful` entries |
| `apps-cronjobs-defaultCronJob` | `apps-cronjobs` entries |
| `apps-jobs-defaultJob` | `apps-jobs` entries |
| `apps-ingresses-defaultIngress` | `apps-ingresses` entries |
| `apps-secrets-defaultSecret` | `apps-secrets` entries |
| `apps-configmaps-defaultConfigmap` | `apps-configmaps` entries |
| `apps-karpenter-defaultNodePool` | `apps-karpenter-node-pool` entries |
| `apps-karpenter-defaultNodeClass` | `apps-karpenter-node-class` entries |

An example defaults file:

```yaml
# .helm/helm-apps-defaults.yaml

apps-defaults:
  enabled: false

apps-default-library-app:
  _include: ["apps-defaults"]
  imagePullSecrets: |
    - name: registrysecret

apps-stateless-defaultApp:
  _include: ["apps-default-library-app"]
  revisionHistoryLimit: 3
  strategy:
    _default: |
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 20%
        maxUnavailable: 50%
    prod: |
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 20%
        maxUnavailable: 25%
  podDisruptionBudget:
    enabled: true
    maxUnavailable: "15%"
  verticalPodAutoscaler:
    enabled: true
    updateMode: "Off"
    resourcePolicy: |
      {}
  horizontalPodAutoscaler:
    enabled: false
  service:
    enabled: false
    name: "{{ $.CurrentApp.name }}"

apps-ingresses-defaultIngress:
  _include: ["apps-defaults"]
  class: "nginx"
```

Reference it from `values.yaml`:

```yaml
global:
  _includes:
    _include_from_file: helm-apps-defaults.yaml
```

This keeps project-level `values.yaml` clean: each app entry only carries keys that differ from the defaults.

---

## 9. Karpenter Node Provisioning

The library supports two Karpenter resource types:

- `apps-karpenter-node-pool` — generates a `NodePool` (API group `karpenter.sh/v1`)
- `apps-karpenter-node-class` — generates an `EC2NodeClass` (API group `karpenter.k8s.aws/v1`)

### Separate keys

```yaml
apps-karpenter-node-class:
  default:
    _include: ["apps-karpenter-defaultNodeClass"]
    role: "KarpenterNodeRole"
    amiFamily: "AL2023"
    amiSelectorTerms: |
      - alias: al2023@latest
    subnetSelectorTerms: |
      - tags:
          karpenter.sh/discovery: my-cluster
    securityGroupSelectorTerms: |
      - tags:
          karpenter.sh/discovery: my-cluster
    tags: |
      Environment: production

apps-karpenter-node-pool:
  general:
    _include: ["apps-karpenter-defaultNodePool"]
    nodeClassRef:
      name: default
    requirements: |
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["on-demand"]
      - key: node.kubernetes.io/instance-type
        operator: In
        values: ["m5.large", "m5.xlarge"]
    limits: |
      cpu: "100"
      memory: 400Gi
    disruption:
      consolidationPolicy: WhenEmptyOrUnderutilized
      consolidateAfter: "1m"
```

### Combined `apps-karpenter` key

The `apps-karpenter` key is an alias for `apps-karpenter-node-pool` and can be used when all entries are node pools and you prefer a shorter key name.

```yaml
apps-karpenter:
  spot-pool:
    _include: ["apps-karpenter-defaultNodePool"]
    nodeClassRef:
      name: default
    requirements: |
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot"]
```

Both `apps-karpenter-node-pool` and `apps-karpenter-node-class` support the full `_include`, per-environment override, and Go template features described in this guide.

---

## 10. Logic vs Config Separation

The helm-apps library enforces a clean separation between logic and configuration:

- **Logic** lives in the library templates (`charts/helm-apps/templates/`). These files are versioned and released independently. Application repositories do not contain template logic — they only consume it.

- **Configuration** lives in `.helm/values.yaml` (and optionally `.helm/helm-apps-defaults.yaml` and `.helm/secret-values.yaml`). This is the only file that application teams need to edit.

In practice, an application repository's `.helm/` directory contains:

```
.helm/
  Chart.yaml                        # declares helm-apps as a dependency
  helm-apps-defaults.yaml           # shared include blocks (optional)
  values.yaml                       # all app configuration
  secret-values.yaml                # encrypted secrets (optional)
  templates/
    init-helm-apps-library.yaml     # one-liner: includes "apps-utils.init-library"
```

No other template files are needed. Adding a new Kubernetes resource means adding entries to `values.yaml` — not writing new template YAML.
