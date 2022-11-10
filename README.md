# helm-kubectl
A helm plugin for ArgoCD to support the lookup function

See https://github.com/argoproj/argo-cd/issues/5202 for upstream discussion.

# Usage

## Helm

helm-kubectl can be only used as downloader plugin.

```bash
helm template <chart-name> --set-file=valuesKey=kubectl://<namespace>/<kind>/<name>/<output>
```

The file name `kubectl://<namespace>/<kind>/<name>/<output>` will be translated into `kubectl -n <namespace> <kind> <name> -o <output>`.

Output transformation (like base64 for secrets) can be archived through helm template functions.

For cluster-wide resources, omit the namespace but keep the slashes. For example:

```bash
helm template <chart-name> --set-file=valuesKey=kubectl:///namespace/default
```

To get a certain value form the kubernetes manifest, the output can be modified through `kubectl` output parameter. 
You can use [JSONPath](https://kubernetes.io/docs/reference/kubectl/jsonpath/) to grab a specific key, e.g.

```bash
helm template <chart-name> --set-file='valuesKey=kubectl://default/secret/mysql/jsonpath={.data.rootPassword}'
```

### Backslash support

Backslash needs to be repeated 4 times to ensured the reached the kubectl command.

Example:

```bash
kubectl get nodes -o "jsonpath={.items[*].metadata.labels.kubernetes\.io/os}{'\n'}"
```

becomes:

```bash
helm template values --set-file="resources.requests.cpu=kubectl:///nodes//jsonpath={.items[*].metadata.labels.kubernetes\\\\.io/os}{'\\\\n'}"
```

### Ignore errors

To ignore errors (e.g. not found), put a question mark after the protocol scheme, e.g.:

`kubectl://?default/namespace/does-not-exists"`

## ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app
spec:
  project: default
  source:
    repoURL: https://github.com/jkroepke/helm-kubectl
    helm:
      fileParameters:
        - name: mysql.rootPassword
          path: kubectl://?default/secret/mysql/jsonpath={.data.rootPassword}
  destination:
    name: kubernetes
    namespace: default
```


# Installation

## Local

```bash
helm plugin install https://github.com/jkroepke/helm-kubectl
```

## ArgoCD

The given value file based on [argocd helm chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd). A initContainer will be used to install
the helm plugin

<details>
<summary>values.yaml</summary>

```yaml
repoServer:
  clusterAdminAccess:
    enabled: true
  clusterRoleRules:
    # -- Enable custom rules for the Repo server's Cluster Role resource
    enabled: false
    # -- List of custom rules for the Repo server's Cluster Role resource
    rules:
    - apiGroups:
      - '*'
      resources:
      - '*'
      verbs:
      - 'list'
      - 'get'
  env:
    - name: HELM_PLUGINS
      value: /custom-tools/helm-plugins/
    - name: HELM_KUBECTL_KUBECTL_PATH
      value: /custom-tools/kubectl

  serviceAccount:
    create: true

  volumes:
    - name: custom-tools
      emptyDir: {}
  volumeMounts:
    - mountPath: /custom-tools
      name: custom-tools

  initContainers:
    - name: download-tools
      image: alpine:latest
      command: [sh, -ec]
      env:
        - name: HELM_KUBECTL_VERSION
          value: "1.0.0"
        - name: KUBECTL_VERSION
          value: "1.24.3"
      args:
        - |
          mkdir -p /custom-tools/helm-plugins
          wget -qO- https://github.com/jkroepke/helm-kubectl/releases/download/v${HELM_KUBECTL_VERSION}/helm-kubectl.tar.gz | tar -C /custom-tools/helm-plugins -xzf-;
          wget -qO /custom-tools/kubectl https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl

          chmod +x /custom-tools/*
      volumeMounts:
        - mountPath: /custom-tools
          name: custom-tools

server:
  config:
    helm.valuesFileSchemes: >-
      kubectl,
      http,
      https
```
</details>
