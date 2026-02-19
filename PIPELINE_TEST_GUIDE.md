# 🚀 Pipeline Test Guide

Dieses Dokument beschreibt wie man die optimierte Deployment Pipeline testet.

## ✅ Voraussetzungen

- OpenShift Cluster ist erreichbar (`oc status`)
- GitHub CLI ist installiert (`gh --version`)
- Helm ist installiert (`helm version`)
- GitHub Secrets sind konfiguriert (`OPENSHIFT_TOKEN`)

---

## 🧪 Test 1: Manuelle Deployment-Abläufe

### Schritt 1: Cleanup alte Releases
```bash
# Skript ausführbar machen
chmod +x scripts/cleanup-releases.sh

# Alte Releases entfernen
./scripts/cleanup-releases.sh pokamr-dev

# Erwartet: Meldung welche Releases entfernt wurden
# ✅ Removed: 5 releases
# ⏭️  Skipped: 3 releases
```

### Schritt 2: Helm Dependencies bauen
```bash
cd charts/opentelemetry-demo
helm dependency build
cd ../../..

# Erwartet: Charts heruntergeladen und Abhängigkeiten aufgelöst
```

### Schritt 3: Deployment durchführen
```bash
helm upgrade --install otel-demo ./charts/opentelemetry-demo \
  -n pokamr-dev \
  -f ./charts/opentelemetry-demo/ocp-values.yaml \
  --wait --timeout=10m \
  --cleanup-on-fail

# Erwartet: Erfolgreiches Deployment
# STATUS: deployed
```

### Schritt 4: Routes erstellen
```bash
chmod +x scripts/create-routes.sh
./scripts/create-routes.sh pokamr-dev dev

# Erwartet: Routes für alle Services erstellt
# ✅ Route created: https://frontend-pokamr-dev.apps...
# ✅ Route created: https://grafana-pokamr-dev.apps...
```

### Schritt 5: Zugriff überprüfen
```bash
# Verfügbare Routes anzeigen
oc get routes -n pokamr-dev

# Jede Route sollte einen Host haben
# NAME           HOST/PORT                                  PATH   SERVICES      ...
# frontend       frontend-pokamr-dev.apps.rm3.7wse...       /      frontend
# grafana        grafana-pokamr-dev.apps.rm3.7wse...        /      grafana
```

---

## 🔄 Test 2: GitHub Actions Workflow

### Schritt 1: Workflow triggern
```bash
# Option A: Manual Trigger via CLI
gh workflow run deploy-openshift.yml -f environment=dev

# Option B: Automatisch via Git Push
git commit -m "test: trigger deployment pipeline"
git push origin main
```

### Schritt 2: Workflow beobachten
```bash
# Live Logs anschauen
gh run list --workflow=deploy-openshift.yml

# Spezifischen Run abrufen
gh run view <run-id> --log

# Status überprüfen
gh run view <run-id> --json conclusion
```

### Schritt 3: Ergebnisse überprüfen
```bash
# Im GitHub Actions Web UI überprüfen:
# https://github.com/pokam1988/opentelemetry-observability/actions

# Dort sollte zu sehen sein:
# ✅ validate - OK
# ✅ security - OK (oder Warnungen)
# ✅ deploy-dev - OK
# ✅ deploy-helm - OK

# Deployment Summary anschauen:
# - Pod Status
# - Verfügbare Routes
# - Quick Links zu Services
```

---

## 📊 Test 3: Konfiguration-Update

Teste dass neue Konfigurationen automatisch deployed werden:

### Änderung vornehmen
```bash
# Ändere ein Wert in der Konfiguration
nano charts/opentelemetry-demo/ocp-values.yaml

# Z.B. Grafana Admin Password ändern
# grafana:
#   adminPassword: "newpassword123"
```

### Committieren und Pushen
```bash
git add charts/opentelemetry-demo/ocp-values.yaml
git commit -m "feat: update grafana credentials"
git push origin main
```

### Automatisches Deployment überprüfen
```bash
# Workflow sollte automatisch starten
gh run list --workflow=deploy-openshift.yml

# Nach Completion neue Konfiguration überprüfen
helm get values otel-demo -n pokamr-dev | grep -A 5 "adminPassword"
```

---

## 🔐 Test 4: Sicherheits-Features

### Route TLS Terminierung
```bash
# Überprüfe dass alle Routes HTTPS verwenden
oc get routes -n pokamr-dev -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.tls.termination}{"\n"}{end}'

# Erwartet: alle sollten "edge" sein
# frontend: edge
# grafana: edge
# prometheus: edge
```

### HTTP→HTTPS Redirect
```bash
# Teste Redirect
curl -i http://frontend-pokamr-dev.apps.rm3.7wse.p1.openshiftapps.com 2>&1 | grep -i "location\|301\|308"

# Sollte 301 oder 308 Redirect zu HTTPS zeigen
```

---

## 🏥 Test 5: Failure Recovery

Teste dass sich der Workflow von Fehlern erholt:

### Test: Falscher Values File
```bash
# Workflow mit ungültigem Values File triggern
# (Simuliere durch Änderung der VALUES_FILE Variable)

# Workflow sollte:
# ✅ Fehler erkennen
# ✅ Cleanup durchführen (--cleanup-on-fail)
# ✅ Fehlgeschlagenen Deploy rückgängig machen
# ✅ Letzte stabile Version bleiben lassen
```

### Test: Pods nicht ready
```bash
# Wenn Pods zu lange brauchen:
# Workflow hat 10min timeout eingestellt
# Sollte gracefully fehlschlagen und keine incomplete Deployments hinterlassen
```

---

## 📈 Test 6: Skalierungs-Test

Teste dass größere Deployments funktionieren:

```bash
# Erhöhe Pod-Replicas in ocp-values.yaml
components:
  frontend:
    replicas: 3         # statt 1
  product-catalog:
    replicas: 2         # statt 1

# Deploye neue Konfiguration
git commit -am "test: scale up components"
git push origin main

# Überprüfe dass alle Pods starten
oc get pods -n pokamr-dev -w

# Workflow sollte mit größerer Last umgehen können
helm status otel-demo -n pokamr-dev
```

---

## 📋 Checkliste für erfolgreiches Testing

- [ ] Cleanup Script funktioniert (`scripts/cleanup-releases.sh`)
- [ ] Helm Dependencies bauen sich (Abhängigkeiten auflösen)
- [ ] Deployment erfolgreich (`helm status otel-demo`)
- [ ] Routes erstellt werden (`oc get routes`)
- [ ] Alle Routes HTTPS haben (`spec.tls.termination: edge`)
- [ ] Services über Routes erreichbar (curl Test)
- [ ] GitHub Workflow automatisch triggert
- [ ] Deployment Summary generiert wird
- [ ] Secrets / Credentials sicher behandelt
- [ ] Fehler-handling funktioniert (Rollback, Cleanup)

---

## 🐛 Troubleshooting während Testing

### Routes werden nicht erstellt
```bash
# Manual erstellen
oc expose svc frontend -n pokamr-dev --port=8080 --name=frontend
oc patch route frontend -n pokamr-dev \
  -p '{"spec":{"tls":{"termination":"edge"}}}'
```

### Helm Deployment hängt
```bash
# Mit Kill Signal stoppen
# In anderem Terminal:
helm uninstall otel-demo -n pokamr-dev
```

### Workflow läuft aber zeigt keine Logs
```bash
# GitHub Actions Debug Mode einschalten
# Neuen Secret hinzufügen: ACTIONS_STEP_DEBUG = true

# Dann Workflow neu starten
```

---

## ✨ Success Criteria

Alles ist erfolgreich wenn:

✅ **Cleanup Phase**
- Alte Releases werden entfernt
- Keine "ownership metadata" Fehler

✅ **Deployment Phase**
- Helm Release deployed erfolgreich
- Alle Container Pods sind Running
- ServiceAccounts korrekt konfiguriert

✅ **Routes Phase**
- Routes für Frontend, Grafana, Prometheus existieren
- Alle Routes haben TLS Edge Termination
- HTTP→HTTPS Redirect funktioniert

✅ **Verification Phase**
- Health Checks bestehen
- Deployment Summary ist verfügbar
- Services sind über URLs erreichbar

---

**Last Updated:** 2026-02-19  
**Test Version:** 1.0
