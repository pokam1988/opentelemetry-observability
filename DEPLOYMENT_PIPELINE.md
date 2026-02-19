# GitHub Actions Deployment Pipeline - Dokumentation

## 🎯 Überblick

Die GitHub Actions Pipeline automatisiert die komplette Deployment-Prozess:
1. ✅ **Validierung** - Helm Chart und Kubernetes Manifeste prüfen
2. 🔒 **Sicherheit** - Compliance Scanning mit Trivy
3. 🧹 **Cleanup** - Alte Helm Releases entfernen
4. 🚀 **Deployment** - Neue Konfiguration deployen
5. 🌐 **Routes** - OpenShift Routes automatisch erstellen
6. ✔️ **Verifikation** - Gesundheitschecks durchführen

---

## 📋 Workflow-Details

### Pre-Deployment Phase
```
Validierung → Sicherheit Scan → Nur bei main/workflow_dispatch
```

### Deployment Phase
```
Cleanup alte Releases
    ↓
Helm Dependencies bauen
    ↓
ServiceAccount Konflikte beheben
    ↓
Helm Release deployen
    ↓
OpenShift Routes erstellen
    ↓
Health Checks
```

---

## 🚀 Trigger-Methoden

### Methode 1: Per Git Push (Automatisch)
```bash
git push origin main
# Oder auf Feature Branch
git push origin feature-xyz
```
**Triggerung:** Automatisch bei Push auf `main` oder Feature Branches

### Methode 2: Pull Request (Automatisch)
```bash
git push origin feature/my-feature
# Erstelle PR gegen main
```
**Triggerung:** Validierung und Security Scan (kein Deployment)

### Methode 3: Manual Workflow Dispatch
```bash
gh workflow run deploy-openshift.yml -f environment=dev
```

**Via Web UI:**
1. GitHub.com → Actions
2. "Deploy OpenTelemetry Demo to OpenShift" 
3. "Run workflow"
4. Branch: `main`
5. Environment: `dev`

---

## 🛠️ Was geschieht beim Deployment

### 1. Cleanup alter Releases
```bash
# Diese alten Releases werden automatisch gelöscht:
helm uninstall grafana
helm uninstall tempo
helm uninstall prometheus
helm uninstall loki
helm uninstall jaeger
helm uninstall opensearch
helm uninstall otel-collector-backend
helm uninstall otel-collector-gateway
# ... etc
```

### 2. Helm Dependencies bauen
```bash
helm dependency build ./charts/opentelemetry-demo
```

### 3. Neue Konfiguration deployen
```bash
helm upgrade --install otel-demo ./charts/opentelemetry-demo \
  --namespace pokamr-dev \
  -f ./charts/opentelemetry-demo/ocp-values.yaml \
  --wait --timeout=10m \
  --cleanup-on-fail
```

### 4. Routes automatisch erstellen
Der Workflow erstellt automatisch Routes für:
- `frontend` → HTTP/HTTPS mit Edge Termination
- `frontend-proxy` → HTTP/HTTPS mit Redirect
- `grafana` → Dashboards
- `prometheus` → Metrics
- `jaeger-query` → Trace UI
- `tempo` → Trace Storage

Alle Routes verwenden:
- **TLS Termination:** Edge (OpenShift managed certificates)
- **HTTP Redirect:** Automatic HTTP → HTTPS redirect

---

## 📊 Deployment-Ausgabe

### GitHub Actions Summary
Nach jedem erfolgreichen Deployment zeigt die Pipeline:

```markdown
## 🚀 Deployment Summary
**Environment:** Development
**Namespace:** pokamr-dev
**Application:** otel-demo
**Release Date:** 2026-02-19 12:30:15

### 📊 Pod Status
frontend-98ddcb4b4-xmc7m                  1/1     Running
otel-collector-7db6bb4b86-7jhjb           1/1     Running
grafana-55cc845b55-shjqs                  1/1     Running
prometheus-8db775fd6-999h4                1/1     Running
tempo-0                                   1/1     Running

### 🔗 Access URLs
| Service | URL |
|---------|-----|
| frontend | https://frontend-pokamr-dev.apps.rm3.7wse.p1.openshiftapps.com |
| grafana | https://grafana-pokamr-dev.apps.rm3.7wse.p1.openshiftapps.com |
| prometheus | https://prometheus-pokamr-dev.apps.rm3.7wse.p1.openshiftapps.com |
```

---

## 🔧 Manuelle Komplement-Commands

### Routes manuell erstellen
```bash
# Nutzt das vorbereitete Script
chmod +x scripts/create-routes.sh
./scripts/create-routes.sh pokamr-dev dev

# Oder manuell für einen Service
oc expose svc grafana -n pokamr-dev --port=80 -l app=grafana
oc patch route grafana -n pokamr-dev \
  -p '{"spec":{"tls":{"termination":"edge"}}}'
```

### Alte Releases manuell löschen
```bash
# Nutzt das vorbereitete Script
chmod +x scripts/cleanup-releases.sh
./scripts/cleanup-releases.sh pokamr-dev

# Oder manuell
helm uninstall grafana -n pokamr-dev
helm list -n pokamr-dev
```

### Deployment Status prüfen
```bash
# Helm Status
helm status otel-demo -n pokamr-dev

# Pods
oc get pods -n pokamr-dev -l app.kubernetes.io/instance=otel-demo

# Routes
oc get routes -n pokamr-dev

# Events
oc get events -n pokamr-dev --sort-by='.lastTimestamp'
```

---

## ⚙️ Konfiguration

### Environment Variables (im Workflow)
```yaml
OPENSHIFT_NAMESPACE: pokamr-dev
APP_NAME: otel-demo
CHART_PATH: ./charts/opentelemetry-demo
VALUES_FILE: ./charts/opentelemetry-demo/ocp-values.yaml
```

### Secrets (müssen in GitHub Actions konfiguriert werden)
- `OPENSHIFT_TOKEN` - OpenShift authentication token
- `OPENSHIFT_SERVER` - OpenShift API Server URL

### Ändern der Deploy-Konfiguration
Bearbeite `./charts/opentelemetry-demo/ocp-values.yaml`:
```yaml
# Services anpassen
components:
  frontend:
    enabled: true
    service:
      port: 8080
  
  grafana:
    enabled: true
    # ... weitere Einstellungen
```

Dann pushen - Workflow läuft automatisch!

---

## 📈 Skalierung

### Environment Konfiguration erweitern
Für mehrere Umgebungen (dev, staging, prod):

1. GitHub Environments hinzufügen
2. Für jede Umgebung ein `values-{env}.yaml` erstellen
3. Workflow mit `environment` input anpassen:
   ```yaml
   environment:
     description: 'Environment to deploy to'
     required: true
     type: choice
     options:
       - dev
       - staging
       - prod
   ```

---

## 🔍 Troubleshooting

### Deployment schlägt fehl
1. **Logs prüfen:**
   ```bash
   gh run list --workflow=deploy-openshift.yml
   gh run view <run-id> --log
   ```

2. **Häufige Fehler:**
   - ServiceAccount Ownership Konflikt → Cleanup Script läuft automatisch
   - Helm Timeout → Timeout ist auf 10m eingestellt
   - Route-Erstellung fehlgeschlagen → Manuell mit Script erstellen

### Services nicht erreichbar
```bash
# Route Status prüfen
oc describe route frontend -n pokamr-dev

# Service Status prüfen
oc describe svc frontend -n pokamr-dev

# Pod Logs prüfen
oc logs deployment/frontend -n pokamr-dev --tail=50
```

### Sicher zurückgehen auf altes Release
```bash
helm history otel-demo -n pokamr-dev
helm rollback otel-demo 1 -n pokamr-dev
```

---

## 📚 Weitere Ressourcen

- [Helm Documentation](https://helm.sh/docs/)
- [OpenShift Routes](https://docs.openshift.com/container-platform/4.14/networking/routes/route-configuration.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [OpenTelemetry Demo Chart](https://github.com/open-telemetry/opentelemetry-helm-charts)

---

**Last Updated:** 2026-02-19  
**Pipeline Version:** 2.0  
**Status:** ✅ Production Ready
