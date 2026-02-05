# ArgoCD Configuration Guide

## Quick Start

### 1. Access ArgoCD UI

After deployment, port-forward to ArgoCD server:
```bash
oc port-forward -n argocd svc/argocd-server 8080:443
```

Then visit: `https://localhost:8080`

Default credentials:
- Username: `admin`
- Password: (Get from secret)
  ```bash
  oc get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  ```

### 2. Configure Git Repository Access

If using private repository, configure credentials in ArgoCD:

```bash
# Create Git credentials secret
oc create secret generic git-credentials \
  -n argocd \
  --from-literal=username=<github-username> \
  --from-literal=password=<github-token>
```

Then update the Application resource:
```yaml
source:
  repoURL: <your-private-repo-url>
  credentials:
    name: git-credentials
```

### 3. Application Manifest (Already Created)

The ArgoCD Application resource is automatically created by the workflow:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: otel-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/pokam1988/opentelemetry-observability
    targetRevision: main
    path: charts/opentelemetry-demo
    helm:
      valueFiles:
      - ocp-values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: pokamr-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 1m
```

## Monitoring & Troubleshooting

### Check Application Status
```bash
oc get application otel-demo -n argocd
oc get application otel-demo -n argocd -o yaml
```

### View Sync History
```bash
oc get application otel-demo -n argocd -o jsonpath='{.status.operationState}' | jq .
```

### Check ArgoCD Controller Logs
```bash
oc logs -n argocd deployment/argocd-application-controller -f
```

### Monitor Real-Time Sync
```bash
oc get application otel-demo -n argocd -w
```

## Advanced Configuration

### Custom Health Assessments

Add health rules for custom resource types:
```bash
oc create configmap argocd-cm -n argocd \
  --from-literal=resource.customizations=... \
  --dry-run=client -o yaml | oc apply -f -
```

### Notifications (Slack/Email)

Configure ArgoCD notifications:
```bash
oc edit secret/argocd-notifications-secret -n argocd
```

### RBAC Configuration

Grant users access to ArgoCD:
```bash
oc edit cm/argocd-rbac-cm -n argocd
```

Example RBAC policy:
```
p, role:developer, applications, get, */*, allow
p, role:developer, applications, sync, */*, allow
```

## Sync Policies Explained

### Automated Sync
```yaml
syncPolicy:
  automated:
    prune: true        # Delete cluster resources not in Git
    selfHeal: true     # Sync on cluster drift
```

### Manual Sync
```yaml
syncPolicy:
  syncOptions:
  - Validate=false
```

### Retry Logic
```yaml
retry:
  limit: 5
  backoff:
    duration: 5s
    factor: 2          # Exponential backoff
    maxDuration: 1m
```

## Common Use Cases

### Use Case 1: Promote Changes Through Environments

**Scenario:** Dev → Staging → Prod

```bash
# Create separate branches
git checkout -b dev
git checkout -b staging
git checkout -b prod

# Each branch has own values file
# Create separate Applications:
```

```yaml
---
# dev-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: otel-demo-dev
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/pokam1988/opentelemetry-observability
    targetRevision: dev
    path: charts/opentelemetry-demo
  destination:
    namespace: pokamr-dev

---
# prod-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: otel-demo-prod
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/pokam1988/opentelemetry-observability
    targetRevision: prod
    path: charts/opentelemetry-demo
    helm:
      valueFiles:
      - prod-values.yaml
  destination:
    namespace: pokamr-prod
```

**Deployment Process:**
```bash
# Update chart → push to dev branch
# ArgoCD auto-syncs to pokamr-dev

# After testing → merge to main
# ArgoCD auto-syncs main to pokamr-prod
```

### Use Case 2: Blue-Green Deployment

**Scenario:** Two identical deployments for zero-downtime updates

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: otel-demo-blue
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/pokam1988/opentelemetry-observability
    path: charts/opentelemetry-demo
    helm:
      values: |
        # Blue environment
        ingress:
          weight: 100  # Send all traffic to blue
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: otel-demo-green
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/pokam1988/opentelemetry-observability
    path: charts/opentelemetry-demo
    helm:
      values: |
        # Green environment
        ingress:
          weight: 0    # Send no traffic to green
```

**Switch Traffic:**
```bash
# Test green environment
oc patch application otel-demo-green -n argocd \
  -p '{"spec":{"source":{"helm":{"values":"ingress:\n  weight: 100"}}}}' \
  --type merge

# Rollback by switching back to blue
oc patch application otel-demo-blue -n argocd \
  -p '{"spec":{"source":{"helm":{"values":"ingress:\n  weight: 100"}}}}' \
  --type merge
```

### Use Case 3: Canary Deployment

**Scenario:** Gradually roll out changes to percentage of traffic

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: otel-demo
  namespace: pokamr-dev
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: otel-demo
  service:
    port: 8080
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 5
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
```

## Drift Detection

Monitor for manual changes not tracked in Git:

```bash
# Check if cluster is out of sync
oc get application otel-demo -n argocd -o jsonpath='{.status.sync.status}'

# If OutOfSync, view the diff
oc get application otel-demo -n argocd -o jsonpath='{.status.resources}' | jq '.[] | select(.status != "Synced")'

# Auto-heal by triggering sync
oc patch application otel-demo -n argocd \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' \
  --type merge
```

## Security Best Practices

### 1. Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-network-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: pokamr-dev
    ports:
    - protocol: TCP
      port: 8080
```

### 2. RBAC Configuration
```bash
# Limit user access to specific applications
oc edit cm/argocd-rbac-cm -n argocd
```

```
p, role:dev-team, applications, get, pokamr-dev/*, allow
p, role:dev-team, applications, sync, pokamr-dev/*, allow
p, role:dev-team, applications, get, pokamr-prod/*, deny
```

### 3. Secret Management
```bash
# Use sealed secrets for sensitive data
oc apply -f sealed-secret.yaml

# Or use external secret operator
oc apply -f external-secret.yaml
```

## Backup & Disaster Recovery

### Backup ArgoCD Configuration
```bash
# Backup all Application resources
oc get applications -n argocd -o yaml > argocd-apps-backup.yaml

# Backup ArgoCD secrets
oc get secrets -n argocd -o yaml > argocd-secrets-backup.yaml
```

### Restore ArgoCD Configuration
```bash
# Restore Applications
oc apply -f argocd-apps-backup.yaml

# Restore secrets
oc apply -f argocd-secrets-backup.yaml
```

## Performance Tuning

### Increase Sync Concurrency
```bash
oc set env deployment/argocd-application-controller \
  -n argocd \
  ARGOCD_CONTROLLER_SYNC_QUEUE_CONCURRENCY=10
```

### Adjust Polling Interval
```yaml
spec:
  syncPolicy:
    syncOptions:
    - RespectIgnoreDifferences=true
```

---

## Useful Commands Reference

```bash
# Get all applications
oc get applications -n argocd

# Get detailed app status
oc describe application otel-demo -n argocd

# Force immediate sync
oc patch application otel-demo -n argocd \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' \
  --type merge

# Watch sync progress
oc get application otel-demo -n argocd -w

# Check sync history
oc get application otel-demo -n argocd -o jsonpath='{.status.history}' | jq .

# Delete application (keeps resources)
oc delete application otel-demo -n argocd --cascade=orphan

# Delete application and resources
oc delete application otel-demo -n argocd
```

---

For more information, visit:
- [ArgoCD Documentation](https://argoproj.github.io/argo-cd/)
- [ArgoCD Use Cases](https://argoproj.github.io/argo-cd/use_cases/)
- [ArgoCD FAQs](https://argoproj.github.io/argo-cd/faq/)
