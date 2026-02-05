# 📊 Architecture & Workflow Diagrams

## 1. Deployment Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                                   │
│  (opentelemetry-observability)                                              │
│                                                                              │
│  ├─ .github/workflows/                                                      │
│  │  ├─ deploy-openshift.yml       ← MODIFIED (timeout + ArgoCD)             │
│  │  └─ test-argocd.yml            ← NEW (8 test scenarios)                  │
│  │                                                                           │
│  └─ charts/opentelemetry-demo/                                              │
│     └─ ocp-values.yaml            ← MODIFIED (securityContext fix)          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         ↓ (git push)
┌─────────────────────────────────────────────────────────────────────────────┐
│                       GitHub Actions Workflows                              │
│                                                                              │
│  WORKFLOW: deploy-openshift.yml                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ JOB 1: Validate                                                     │   │
│  │ ├─ Helm lint chart                                                 │   │
│  │ ├─ Build dependencies                                              │   │
│  │ └─ Template manifests                                              │   │
│  │                                                                     │   │
│  │ JOB 2: Security Scan                                               │   │
│  │ └─ Trivy config scan                                               │   │
│  │                                                                     │   │
│  │ JOB 3: Deploy-Dev (Helm Direct) ← FIXED                            │   │
│  │ ├─ Login to OpenShift                                              │   │
│  │ ├─ Add Helm repos                                                  │   │
│  │ ├─ Build dependencies                                              │   │
│  │ ├─ Deploy with helm upgrade                                        │   │
│  │ │  └─ Timeout: 10m (was 5m) ← FIX                                 │   │
│  │ │  └─ --atomic flag ← NEW                                          │   │
│  │ ├─ Verify pods running                                             │   │
│  │ ├─ Health checks                                                   │   │
│  │ └─ Generate summary                                                │   │
│  │                                                                     │   │
│  │ JOB 4: Deploy-ArgoCD (GitOps) ← NEW                                │   │
│  │ ├─ Login to OpenShift                                              │   │
│  │ ├─ Install ArgoCD via Helm                                         │   │
│  │ ├─ Create Application resource                                     │   │
│  │ ├─ Configure auto-sync                                             │   │
│  │ ├─ Monitor sync status                                             │   │
│  │ └─ Verify health                                                   │   │
│  │                                                                     │   │
│  │ JOB 5: Cleanup (PR cleanup)                                        │   │
│  │ └─ Delete PR namespace                                             │   │
│  │                                                                     │   │
│  │ JOB 6: Notify                                                      │   │
│  │ └─ Send deployment status                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  WORKFLOW: test-argocd.yml ← NEW                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ JOB: Test-ArgoCD                                                   │   │
│  │ ├─ Test 1: ArgoCD Installation                                     │   │
│  │ ├─ Test 2: Application Resource                                    │   │
│  │ ├─ Test 3: Manual Sync                                             │   │
│  │ ├─ Test 4: Health & Sync Status                                    │   │
│  │ ├─ Test 5: Rollback Capability                                     │   │
│  │ ├─ Test 6: Pod Accessibility                                       │   │
│  │ ├─ Test 7: Service Discovery                                       │   │
│  │ ├─ Test 8: Configuration Consistency                               │   │
│  │ └─ Generate Test Report                                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
         ↓ (kubectl commands)
┌─────────────────────────────────────────────────────────────────────────────┐
│                      OpenShift Cluster (podkamr-dev)                        │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ Namespace: argocd                                                      │ │
│  │                                                                        │ │
│  │  ├─ Pod: argocd-server                                               │ │
│  │  ├─ Pod: argocd-repo-server                                          │ │
│  │  ├─ Pod: argocd-application-controller                               │ │
│  │  ├─ Pod: argocd-dex-server                                           │ │
│  │  ├─ Service: argocd-server                                           │ │
│  │  ├─ Service: argocd-repo-server                                      │ │
│  │  │                                                                   │ │
│  │  └─ CustomResource: Application (otel-demo)                          │ │
│  │     ├─ Source: GitHub repo (main branch)                             │ │
│  │     ├─ Path: charts/opentelemetry-demo                               │ │
│  │     ├─ Values: ocp-values.yaml ← FIXED                               │ │
│  │     ├─ Sync Policy:                                                  │ │
│  │     │  ├─ Automated: true                                            │ │
│  │     │  ├─ Prune: true                                                │ │
│  │     │  └─ Self-Heal: true                                            │ │
│  │     └─ Status:                                                       │ │
│  │        ├─ Sync: Synced                                               │ │
│  │        └─ Health: Healthy                                            │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ Namespace: pokamr-dev                                                  │ │
│  │                                                                        │ │
│  │  OpenTelemetry Demo Services:                                         │ │
│  │  ├─ Pod: frontend                    ← Running                        │ │
│  │  ├─ Pod: order-service               ← Running                        │ │
│  │  ├─ Pod: payment-service             ← Running                        │ │
│  │  ├─ Pod: inventory-service           ← Running                        │ │
│  │  ├─ Pod: product-catalog-service     ← Running                        │ │
│  │  ├─ Pod: otel-collector              ← Running                        │ │
│  │  ├─ Pod: prometheus                  ← Running                        │ │
│  │  ├─ Pod: grafana                     ← Running                        │ │
│  │  ├─ Pod: jaeger                      ← Running                        │ │
│  │  ├─ Pod: opensearch                  ← Running                        │ │
│  │  ├─ Pod: redis                       ← Running                        │ │
│  │  ├─ ... (more services)              ← Running                        │ │
│  │  │                                                                   │ │
│  │  ├─ Service: frontend                                                │ │
│  │  ├─ Service: otel-collector                                          │ │
│  │  ├─ Service: prometheus                                              │ │
│  │  ├─ Service: grafana                                                 │ │
│  │  ├─ ... (more services)                                              │ │
│  │  │                                                                   │ │
│  │  ├─ ConfigMap: otel-collector-config                                 │ │
│  │  ├─ ConfigMap: prometheus-config                                     │ │
│  │  └─ ConfigMap: grafana-dashboards                                    │ │
│  │                                                                       │ │
│  │  Security Context Applied:                                           │ │
│  │  ├─ runAsNonRoot: true                                               │ │
│  │  ├─ seccompProfile: RuntimeDefault                                   │ │
│  │  ├─ allowPrivilegeEscalation: false ← FIXED                          │ │
│  │  └─ capabilities.drop: ["ALL"]      ← FIXED                          │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Deployment Decision Tree

```
                          START DEPLOYMENT
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │  GitHub Actions Trigger │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │  Validate Chart Syntax  │
                    │  & Dependencies         │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │  Security Scan (Trivy)  │
                    └────────────┬────────────┘
                                 │
                ┌────────────────┴───────────────────┐
                │                                    │
                ▼                                    ▼
        ┌──────────────────┐            ┌──────────────────┐
        │ Deploy-Dev       │            │ Deploy-ArgoCD    │
        │ (Helm Direct)    │            │ (GitOps)         │
        └──────┬───────────┘            └────────┬─────────┘
               │                                 │
        ┌──────▼──────┐              ┌──────────▼──────────┐
        │ helm upgrade │              │ Install ArgoCD     │
        │ --timeout=10m│              │ Create Application │
        │ --atomic     │              │ Auto-sync setup    │
        └──────┬──────┘              └──────────┬──────────┘
               │                                 │
        ┌──────▼──────────────┐      ┌──────────▼──────────┐
        │ Health Checks       │      │ Monitor Sync Status │
        │ - Pod readiness     │      │ - Synced status    │
        │ - Service endpoint  │      │ - Health check     │
        └──────┬──────────────┘      └──────────┬──────────┘
               │                                 │
                └────────────────┬───────────────┘
                                 │
                        ┌────────▼────────┐
                        │  Cleanup & Notify│
                        └────────┬────────┘
                                 │
                        ┌────────▼────────┐
                        │ Run Test Suite   │
                        │ (Optional)       │
                        └────────┬────────┘
                                 │
                                 ▼
                         ┌─────────────────┐
                         │ DEPLOYMENT      │
                         │ COMPLETE ✅     │
                         └─────────────────┘
```

---

## 3. Problem & Solution Flow

```
PROBLEM STATEMENT
├─ Issue 1: Helm Timeout Error
│  └─ "client rate limiter Wait returned an error: context deadline"
│
├─ Issue 2: SecurityContext Warnings  
│  ├─ Unknown field "allowPrivilegeEscalation"
│  └─ Unknown field "capabilities"
│
└─ Requirement: ArgoCD Integration & Testing
   ├─ Deploy with ArgoCD
   ├─ GitOps configuration
   └─ Comprehensive test suite


ROOT CAUSE ANALYSIS
├─ Issue 1 Root Cause
│  └─ Helm timeout of 5 minutes too short for 20+ microservices
│
├─ Issue 2 Root Cause
│  └─ SecurityContext fields applied at wrong YAML level
│     (container-level fields at pod spec level)
│
└─ Requirement Analysis
   ├─ Need GitOps for production
   ├─ Need automated reconciliation
   └─ Need comprehensive validation


SOLUTIONS IMPLEMENTED
├─ Fix #1: Timeout Increase
│  ├─ Increase: 5m → 10m
│  ├─ Add: --atomic flag for auto-rollback
│  └─ Benefits:
│     ├─ Prevents premature timeouts
│     ├─ Allows cluster to initialize services
│     └─ Auto-rollback on failure
│
├─ Fix #2: SecurityContext Reordering
│  ├─ Move pod-level fields first
│  ├─ Keep container-level fields after
│  └─ Benefits:
│     ├─ Eliminates API warnings
│     ├─ Correct YAML structure
│     └─ Compliant with Kubernetes API
│
└─ New Features: ArgoCD Integration
   ├─ Helm install ArgoCD
   ├─ Create Application resource
   ├─ Configure auto-sync
   ├─ Setup self-healing
   └─ Benefits:
      ├─ GitOps best practices
      ├─ Automatic reconciliation
      ├─ Production-ready setup
      └─ Comprehensive testing


RESULTS
├─ ✅ No more rate limiter timeouts
├─ ✅ No more SecurityContext warnings
├─ ✅ ArgoCD deployed and synced
├─ ✅ Auto-sync and self-healing enabled
├─ ✅ 8-test comprehensive test suite
├─ ✅ Detailed documentation provided
└─ ✅ Ready for production deployment
```

---

## 4. Service Dependency Graph

```
                        ┌──────────────────┐
                        │   GitHub Pages   │
                        │    (Frontend)    │
                        └────────┬─────────┘
                                 │
                    ┌────────────┴──────────────┐
                    │                           │
                    ▼                           ▼
            ┌───────────────┐         ┌──────────────────┐
            │ Order Service │         │ Product Catalog  │
            └───────┬───────┘         └────────┬─────────┘
                    │                          │
                    │  ┌───────────────────────┘
                    │  │
                    ▼  ▼
            ┌───────────────────┐
            │ Inventory Service │
            └────────┬──────────┘
                     │
                     ▼
            ┌───────────────────┐
            │ Payment Service   │
            └────────┬──────────┘
                     │
                     ▼
            ┌───────────────────┐
            │   Redis Cache     │
            └────────┬──────────┘
                     │
    ┌────────────────┴────────────────┬────────────────┐
    │                                 │                │
    ▼                                 ▼                ▼
┌─────────────────┐         ┌──────────────────┐  ┌────────────────┐
│ OTel Collector  │         │ OpenSearch       │  │ Jaeger Tracing │
└────────┬────────┘         └────────┬─────────┘  └────────┬───────┘
         │                           │                     │
         ├───────────────────────────┼─────────────────────┤
         │                           │                     │
         ▼                           ▼                     ▼
    ┌──────────────────────────────────────────────────────┐
    │            Observability Platform                     │
    ├──────────────────────────────────────────────────────┤
    │ ├─ Prometheus (metrics)                              │
    │ ├─ Loki (logs)                                       │
    │ ├─ Tempo (traces)                                    │
    │ └─ Grafana (dashboard)                               │
    └──────────────────────────────────────────────────────┘
```

---

## 5. Sync State Machine (ArgoCD)

```
                    ┌──────────────────────┐
                    │   Git Repository     │
                    │  (Source of Truth)   │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼────────────┐
                    │   ArgoCD Controller   │
                    │  (Reconciliation)     │
                    └──────────┬────────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
         ┌──────────┐   ┌──────────┐   ┌──────────┐
         │  Synced  │◄──┤ OutOfSync├──►│ Syncing  │
         │ Healthy  │   │          │   │          │
         └──────┬───┘   └──────────┘   └──────┬───┘
                │                             │
                │ Auto-Healing               │ Fetch Latest
                │ (every 3 min)              │ (monitoring)
                │                            │
                ├────────────────────────────┘
                │
                ▼ (Drift Detection)
         ┌──────────────────┐
         │  If Cluster      │
         │  Changes (manual)│
         └────────┬─────────┘
                  │
                  ▼
          ┌─────────────────┐
          │  Auto Remediate │
          │  (if enabled)   │
          └────────┬────────┘
                   │
                   ▼
          ┌──────────────────┐
          │  Back to Synced  │
          └──────────────────┘


SYNC POLICIES APPLIED:
├─ Automated Sync: Enabled
├─ Self-Healing: Enabled
├─ Pruning: Enabled
├─ Retry Limit: 5
├─ Retry Backoff: Exponential (5s base)
└─ Max Duration: 1 minute
```

---

## 6. Component Timeline

```
TIME    ACTION
────────────────────────────────────────────────────────────────
0:00    Workflow triggered
        ├─ Checkout code
        └─ Setup tools (Helm, OC CLI)

0:30    Validation job
        ├─ Lint Helm chart
        ├─ Check dependencies
        └─ Template manifests

1:00    Security scanning
        └─ Trivy config scan

2:00    Deploy-Dev job starts
        ├─ Login to OpenShift
        ├─ Add Helm repos (parallel)
        ├─ Build dependencies
        └─ Start Helm deployment

2:30    Helm deployment in progress
        ├─ Create pods
        ├─ Pull images
        ├─ Initialize containers
        └─ Wait for readiness

6:00    Helm deployment continuing
        ├─ Services starting
        ├─ Configuration loading
        └─ Health checks passing

10:00   Helm deployment completes ✅
        ├─ All pods running
        ├─ Services initialized
        └─ Generate deployment summary

10:30   Deploy-ArgoCD job starts (parallel)
        ├─ Login to OpenShift
        ├─ Install ArgoCD
        ├─ Create Application resource
        └─ Monitor sync

12:00   ArgoCD syncing
        ├─ Clone git repo
        ├─ Render manifests
        └─ Apply resources

14:00   ArgoCD sync complete ✅
        ├─ Application synced
        ├─ Health status verified
        └─ All tests pass

15:00   Test-ArgoCD workflow (optional)
        ├─ 8 comprehensive tests
        ├─ Validation checks
        └─ Generate report

20:00   All workflows complete ✅
        ├─ Cleanup job runs
        ├─ Notification sent
        └─ Status update posted
```

---

## 7. Data Flow Diagram

```
┌────────────────────────────────┐
│   Git Repository               │
│  - Helm chart                  │
│  - Values files                │
│  - Workflow definitions        │
└─────────────┬──────────────────┘
              │
              │ (git push)
              ▼
┌────────────────────────────────┐
│   GitHub Actions               │
│  - Validate                    │
│  - Security Scan               │
│  - Deploy jobs                 │
└─────────────┬──────────────────┘
              │
         ┌────┴─────┐
         │           │
         ▼           ▼
┌──────────────┐  ┌──────────────────┐
│  Helm CLI    │  │  ArgoCD Server   │
│  - Chart     │  │  - Application CR│
│  - Values    │  │  - Sync Status   │
└────────┬─────┘  └────────┬─────────┘
         │                 │
         └────────┬────────┘
                  │
                  ▼
┌────────────────────────────────┐
│  OpenShift Kubernetes API      │
│  - Create/Update resources     │
│  - Monitor status              │
│  - Apply RBAC policies         │
└─────────────┬──────────────────┘
              │
    ┌─────────┼─────────────┐
    │         │             │
    ▼         ▼             ▼
┌────────┐ ┌───────┐  ┌────────────┐
│ Pods   │ │ Svcs  │  │ ConfigMaps │
└────────┘ └───────┘  └────────────┘
    │         │             │
    └─────────┼─────────────┘
              │
              ▼
┌────────────────────────────────┐
│   OpenTelemetry Demo           │
│   - Tracing                    │
│   - Metrics                    │
│   - Logs                       │
└────────────────────────────────┘
```

---

This completes the comprehensive visual documentation of your OpenTelemetry Demo deployment architecture.
