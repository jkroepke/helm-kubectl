# helm-kubectl
A helm plugin for ArgoCD to support the lookup function

See https://github.com/argoproj/argo-cd/issues/5202 for upstream discussion.

# Usage

## Helm

helm-kubectl can be only used as downloader plugin.

```bash
helm template <chart-name> --set-file=valuesKey=kubectl://<namespace>/<kind>/<name>/<label-list>|<label-IFS>|<label-api-method>?<label-api-args>/<output>
```

The file name `kubectl://<namespace>/<kind>/<name>/<label-list>|<label-IFS>|<label-api-method>?<label-api-args>/<output>` will be translated into `kubectl -n <namespace> <kind> -l <labels> <name> -o <output>`.

Output transformation (like base64 for secrets) can be archived through helm template functions.

For cluster-wide resources, omit the namespace but keep the slashes. For example:

```bash
helm template <chart-name> --set-file=valuesKey=kubectl:///namespace/default/
```

To get a certain value form the kubernetes manifest, the output can be modified through `kubectl` output parameter. 
You can use [JSONPath](https://kubernetes.io/docs/reference/kubectl/jsonpath/) to grab a specific key, e.g.

```bash
helm template <chart-name> --set-file='valuesKey=kubectl://default/secret/mysql//jsonpath={.data.rootPassword}'
```

### Backslash support

Backslash needs to be repeated 4 times to ensured the reached the kubectl command.

Example:

```bash
kubectl get nodes -o "jsonpath={.items[*].metadata.labels.kubernetes\.io/os}{'\n'}"
```

becomes:

```bash
helm template values --set-file="resources.requests.cpu=kubectl:///nodes///jsonpath={.items[*].metadata.labels.kubernetes\\\\.io/os}{'\\\\n'}"
```


## Label Feature

The standard use of helm `lookup` is extended with this plugin: fetching resources based on labels is possible. Always prefer double quotes `""` over single quotes `''` when using the label feature. The single quote behavior is not treated.

Don't input a `<name>` when using the label feature, as kubectl cannot run with both a labels and a name defined.

```bash
helm template <chart-name> --set-file="valuesKey=kubectl:///nodes//argocd=true||/jsonpath={.items[*].metadata.labels.kubernetes\\\\.io/os}"
#linux linux      <----- Returned by executed 'kubectl ... jsonpath'. It means that 2 linux nodes matched
```

The example above gets all the `kubernetes.io/os` labels of the nodes having the label `argocd: true`.


## Label API

Sometimes when using the label feature, this is not convenient to deal with all matches and we want a specific behavior as extracting a single value, so an API has been implemented.

`all` (or empty sting): preserve all matches. See example in upper section.

`get?n`: get the nth match. Element's index starts from 0. An error occurs if the index is out of range.

```bash
helm template <chart-name> --set-file="valuesKey=kubectl:///nodes//argocd=true| |get?0/jsonpath={.items[*].metadata.labels.kubernetes\\\\.io/os}"
#linux     # Returned by executed 'kubectl ... jsonpath'. Keeps only index '0' from the previous example
```

`same`: makes sure that all elements are equals. If yes it returns the element, or an error occurs otherwise. With the example below, if the `helm template` command is used to install argocd, it can be used to make sure that argocd is installed on nodes having the same operating system, and fetching the value of this operating system.

```bash
helm template <chart-name> --set-file="valuesKey=kubectl:///nodes//argocd=true| |same/jsonpath={.items[*].metadata.labels.kubernetes\\\\.io/os}"
#linux     # Returned by executed 'kubectl ... jsonpath'. From the previous example, all matches have the same os so it successfully returns the label value
```

The `<label-IFS>` tells the API how to read the string output (of the kubectl command) as a sentence of matches. By default, the IFS is set to `\n\t` so `\n` or `\t` in the output defines a new match. Be careful when defining your `<output>` and `<label-IFS>`. Always best to give a try upstream with `kubectl`.


### Ignore errors

To ignore errors (e.g. not found), put a question mark after the protocol scheme, e.g.:

`kubectl://?default/namespace/does-not-exists/`

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
          path: kubectl://?default/secret/mysql//jsonpath={.data.rootPassword}
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
