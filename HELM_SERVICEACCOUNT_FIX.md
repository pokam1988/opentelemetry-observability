# Helm ServiceAccount Ownership Konflikt - Lösungsanleitung

## Problem
Fehler bei der Helm-Installation:
```
Error: Unable to continue with install: ServiceAccount "grafana" in namespace "pokamr-dev" 
exists and cannot be imported into the current release: invalid ownership metadata; 
annotation validation error: key "meta.helm.sh/release-name" must equal "otel-demo": 
current value is "grafana"
```

## Ursache
- Ein ServiceAccount namens "grafana" existiert bereits im Namespace
- Der ServiceAccount gehört zu einem früheren Release namens "grafana"
- Der aktuelle "otel-demo" Release versucht, denselben ServiceAccount zu übernehmen
- Helm blockiert dies wegen Metadaten-Konflikten

## Lösungen

### 🔧 Lösung 1: Automatisch via GitHub Actions (EMPFOHLEN)
Die GitHub Pipeline wurde aktualisiert mit automatischem Fix. Aktivieren Sie einfach den Workflow erneut:

```bash
# Option 1: Workflow über CLI triggern
gh workflow run deploy-openshift.yml -f environment=dev

# Option 2: Über GitHub Web UI
# Gehen Sie zu Actions > "Deploy OpenTelemetry Demo to OpenShift" > Run workflow
```

Der Workflow führt automatisch diese Schritte aus:
1. Prüft existierende ServiceAccounts
2. Aktualisiert Helm-Metadaten
3. Installiert das Release neu

### 🔧 Lösung 2: Manuelle Behebung via CLI

#### Schritt 1: Mit OpenShift verbinden
```bash
oc login --token=<YOUR_TOKEN> --server=https://api.rm1.0a51.p1.openshiftapps.com:6443
oc project pokamr-dev
```

#### Schritt 2: ServiceAccount-Metadaten aktualisieren
```bash
# Helm-Annotation mit korrektem Release-Namen hinzufügen
kubectl annotate serviceaccount grafana \
  --namespace pokamr-dev \
  meta.helm.sh/release-name=otel-demo \
  meta.helm.sh/release-namespace=pokamr-dev \
  --overwrite

# Label für Helm Management hinzufügen
kubectl label serviceaccount grafana \
  --namespace pokamr-dev \
  app.kubernetes.io/managed-by=Helm \
  --overwrite
```

#### Schritt 3: Helm Deployment durchführen
```bash
helm repo update
cd ./charts/opentelemetry-demo
helm dependency build

helm upgrade --install otel-demo ./opentelemetry-demo \
  --namespace pokamr-dev \
  -f ./ocp-values.yaml \
  --wait --timeout=10m \
  --cleanup-on-fail
```

### 🔧 Lösung 3: ServiceAccount löschen und neu installieren

⚠️ **Nur wenn keine verwendeten Pods auf diesem ServiceAccount angewiesen sind!**

```bash
# ServiceAccount löschen
oc delete serviceaccount grafana -n pokamr-dev --ignore-not-found=true

# Warten Sie 10 Sekunden
sleep 10

# Helm Deployment durchführen (ServiceAccount wird neu erstellt)
helm upgrade --install otel-demo ./charts/opentelemetry-demo \
  --namespace pokamr-dev \
  -f ./charts/opentelemetry-demo/ocp-values.yaml \
  --wait --timeout=10m \
  --cleanup-on-fail
```

### 🔧 Lösung 4: Nur bestehende Release bereinigen und neu installieren
```bash
# Bestehenden Release entfernen
helm uninstall otel-demo -n pokamr-dev --wait

# 30 Sekunden warten, um sicherzustellen, dass Kubernetes bereinigt ist
sleep 30

# Neu installieren
helm install otel-demo ./charts/opentelemetry-demo \
  --namespace pokamr-dev \
  -f ./charts/opentelemetry-demo/ocp-values.yaml \
  --wait --timeout=10m
```

## 📊 Verifikation

Nach der Behebung überprüfen Sie:

```bash
# 1. Helm Release Status
helm status otel-demo -n pokamr-dev

# 2. ServiceAccount-Metadaten prüfen
kubectl get serviceaccount grafana -n pokamr-dev -o yaml

# 3. Pods Status
oc get pods -n pokamr-dev -l app.kubernetes.io/instance=otel-demo

# 4. Deployment im Chart-Status anschauen
oc get deployment -n pokamr-dev | grep otel
```

## 🛡️ Zukünftige Prävention

Das GitHub-Workflow wurde aktualisiert mit automatischer Bereinigung, daher sollte dieses Problem nicht mehr auftreten.

Wenn Sie zusätzliche präventive Maßnahmen möchten, können diese Optionen erwogen werden:

1. **Grafana fullnameOverride ändern** (in `ocp-values.yaml`):
   ```yaml
   grafana:
     enabled: true
     fullnameOverride: otel-grafana  # Statt: grafana
   ```
   ⚠️ Dies würde ServiceAccount-Namen ändern und Prometheus-Configs anpassen erfordern.

2. **Grafana als separater Release installieren** (außerhalb von otel-demo):
   - Bietet bessere Kontrolle
   - Verhindert Abhängigkeitskonflikte

3. **Namespace vor jedem Deploy löschen**:
   ```bash
   oc delete project pokamr-dev && oc new-project pokamr-dev
   ```

## 📞 Support

Wenn das Problem weiterhin besteht:
1. Überprüfen Sie die Pipeline-Logs in GitHub Actions
2. Führen Sie Lösung 2 oder 3 manuell durch
3. Kontaktieren Sie das DevOps-Team für weitere Hilfe
