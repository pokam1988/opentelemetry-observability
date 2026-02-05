#!/bin/bash
# Quick Deployment Script - OpenTelemetry Demo
# Usage: Copy and paste each section into your terminal

echo "═══════════════════════════════════════════════════════════════"
echo "OpenTelemetry Demo - Quick Deployment Script"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# SECTION 1: PRE-DEPLOYMENT CHECKS
# ============================================================================
echo "📋 SECTION 1: Pre-Deployment Verification"
echo "───────────────────────────────────────────────────────────────────"
echo ""
echo "Run these checks to ensure your environment is ready:"
echo ""

echo "1️⃣  Check OpenShift cluster access:"
echo "    $ oc status"
echo "    $ oc get nodes"
echo ""

echo "2️⃣  Verify GitHub CLI is installed:"
echo "    $ gh version"
echo ""

echo "3️⃣  Verify Helm is installed:"
echo "    $ helm version"
echo ""

echo "4️⃣  Check GitHub secrets are set:"
echo "    $ gh secret list"
echo "    (Should show OPENSHIFT_TOKEN)"
echo ""

echo "5️⃣  Verify GitHub environments exist:"
echo "    $ gh environment list"
echo "    (Should show 'dev' and 'argocd')"
echo ""

echo "6️⃣  Validate Helm chart:"
echo "    $ helm lint ./charts/opentelemetry-demo \\"
echo "      -f ./charts/opentelemetry-demo/ocp-values.yaml"
echo ""

read -p "✅ Press Enter when all pre-deployment checks pass..."

# ============================================================================
# SECTION 2: DEPLOY VIA GITHUB ACTIONS (RECOMMENDED)
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🚀 SECTION 2: Deploy via GitHub Actions"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "Deploying OpenTelemetry Demo to OpenShift..."
echo "This will:"
echo "  1. Validate Helm chart syntax"
echo "  2. Run security scanning"
echo "  3. Deploy via Helm (direct) with 10-minute timeout"
echo "  4. Deploy via ArgoCD (GitOps)"
echo "  5. Verify deployment health"
echo ""

echo "📝 Triggering workflow..."
gh workflow run deploy-openshift.yml -f environment=dev

echo ""
echo "✅ Workflow triggered!"
echo "   View progress: https://github.com/pokam1988/opentelemetry-observability/actions"
echo ""

echo "⏳ Monitoring deployment (this may take 15-30 minutes)..."
echo "   Use: gh run list --workflow=deploy-openshift.yml"
echo ""

read -p "Press Enter to continue once deployment completes..."

# ============================================================================
# SECTION 3: VERIFY HELM DEPLOYMENT
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✔️  SECTION 3: Verify Helm Deployment"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "Checking Helm deployment status..."
echo ""

echo "1️⃣  Check Helm release:"
helm status otel-demo -n pokamr-dev
echo ""

echo "2️⃣  List deployed pods:"
oc get pods -n pokamr-dev
echo ""

echo "3️⃣  Check pod details:"
oc get pods -n pokamr-dev -o wide
echo ""

echo "4️⃣  Monitor pod startup (press Ctrl+C to stop):"
echo "    $ oc get pods -n pokamr-dev -w"
echo ""

# ============================================================================
# SECTION 4: VERIFY ARGOCD DEPLOYMENT
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🎯 SECTION 4: Verify ArgoCD Deployment"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "Checking ArgoCD installation and configuration..."
echo ""

echo "1️⃣  Check ArgoCD pods:"
oc get pods -n argocd
echo ""

echo "2️⃣  Verify ArgoCD Application resource:"
oc get application otel-demo -n argocd
echo ""

echo "3️⃣  Check Application status:"
oc get application otel-demo -n argocd -o jsonpath='{.status.sync.status}'
echo ""
echo "    (Should show 'Synced')"
echo ""

echo "4️⃣  Check Application health:"
oc get application otel-demo -n argocd -o jsonpath='{.status.health.status}'
echo ""
echo "    (Should show 'Healthy')"
echo ""

echo "5️⃣  View detailed Application info:"
oc describe application otel-demo -n argocd
echo ""

# ============================================================================
# SECTION 5: ACCESS ARGOCD UI
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🖥️  SECTION 5: Access ArgoCD User Interface"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "Setting up ArgoCD UI access..."
echo ""

echo "1️⃣  Get admin password:"
ARGOCD_PASSWORD=$(oc get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
echo "    Password: $ARGOCD_PASSWORD"
echo ""

echo "2️⃣  Port-forward to ArgoCD server (in new terminal):"
echo "    $ oc port-forward -n argocd svc/argocd-server 8080:443"
echo ""

echo "3️⃣  Open browser:"
echo "    https://localhost:8080"
echo ""

echo "4️⃣  Login with:"
echo "    Username: admin"
echo "    Password: $ARGOCD_PASSWORD"
echo ""

# ============================================================================
# SECTION 6: RUN TEST SUITE
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🧪 SECTION 6: Run ArgoCD Test Suite"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "Running comprehensive ArgoCD deployment tests..."
echo ""

echo "📝 Triggering test workflow..."
gh workflow run test-argocd.yml -f environment=dev

echo ""
echo "✅ Test workflow triggered!"
echo "   View progress: https://github.com/pokam1988/opentelemetry-observability/actions"
echo ""

echo "⏳ Tests will validate:"
echo "  ✓ ArgoCD installation"
echo "  ✓ Application resource"
echo "  ✓ Sync functionality"
echo "  ✓ Health status"
echo "  ✓ Rollback capability"
echo "  ✓ Pod accessibility"
echo "  ✓ Service discovery"
echo "  ✓ Configuration consistency"
echo ""

read -p "Press Enter when tests complete..."

# ============================================================================
# SECTION 7: MONITOR APPLICATIONS
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📊 SECTION 7: Monitor Deployments"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "Continuous monitoring commands:"
echo ""

echo "1️⃣  Watch pod status (auto-refreshes):"
echo "    $ oc get pods -n pokamr-dev -w"
echo ""

echo "2️⃣  Monitor ArgoCD sync (auto-refreshes):"
echo "    $ oc get application otel-demo -n argocd -w"
echo ""

echo "3️⃣  Check recent events:"
echo "    $ oc get events -n pokamr-dev --sort-by='.lastTimestamp' | tail -10"
echo ""

echo "4️⃣  Monitor resource usage:"
echo "    $ oc top pods -n pokamr-dev"
echo ""

echo "5️⃣  View ArgoCD controller logs:"
echo "    $ oc logs -n argocd deployment/argocd-application-controller -f"
echo ""

# ============================================================================
# SECTION 8: ACCESS APPLICATIONS
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🌐 SECTION 8: Access Deployed Applications"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "Finding application routes..."
echo ""

echo "1️⃣  List available routes:"
oc get routes -n pokamr-dev
echo ""

echo "2️⃣  Access Frontend (if exposed):"
FRONTEND_ROUTE=$(oc get route frontend -n pokamr-dev -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not exposed")
echo "    URL: https://$FRONTEND_ROUTE"
echo ""

echo "3️⃣  Access Grafana (if exposed):"
GRAFANA_ROUTE=$(oc get route grafana -n pokamr-dev -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not exposed")
echo "    URL: https://$GRAFANA_ROUTE"
echo ""

echo "4️⃣  Access Prometheus (if exposed):"
PROMETHEUS_ROUTE=$(oc get route prometheus -n pokamr-dev -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not exposed")
echo "    URL: https://$PROMETHEUS_ROUTE"
echo ""

# ============================================================================
# SECTION 9: TROUBLESHOOTING
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🔧 SECTION 9: Troubleshooting"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "If you encounter issues, try these commands:"
echo ""

echo "❌ Helm deployment failed:"
echo "   $ helm status otel-demo -n pokamr-dev"
echo "   $ helm history otel-demo -n pokamr-dev"
echo "   $ helm rollback otel-demo -n pokamr-dev"
echo ""

echo "❌ Pods not starting:"
echo "   $ oc describe pod <pod-name> -n pokamr-dev"
echo "   $ oc logs <pod-name> -n pokamr-dev"
echo ""

echo "❌ ArgoCD not syncing:"
echo "   $ oc logs -n argocd deployment/argocd-application-controller"
echo "   $ oc get application otel-demo -n argocd -o jsonpath='{.status}' | jq ."
echo ""

echo "❌ SecurityContext warnings:"
echo "   $ grep -A5 'securityContext' charts/opentelemetry-demo/ocp-values.yaml"
echo ""

echo "For detailed help, see:"
echo "   - IMPLEMENTATION_CHECKLIST.md (Step-by-step guide)"
echo "   - DEPLOYMENT_FIX_SUMMARY.md (Detailed fixes explained)"
echo "   - ARGOCD_CONFIGURATION_GUIDE.md (ArgoCD advanced config)"
echo "   - QUICK_REFERENCE.md (Quick command reference)"
echo ""

# ============================================================================
# SECTION 10: SUCCESS VERIFICATION
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ SECTION 10: Success Criteria Checklist"
echo "───────────────────────────────────────────────────────────────────"
echo ""

echo "Your deployment is successful when:"
echo ""
echo "  [ ] All pods in pokamr-dev namespace are 'Running'"
echo "  [ ] ArgoCD pods in argocd namespace are 'Running'"
echo "  [ ] ArgoCD Application status is 'Synced'"
echo "  [ ] ArgoCD Application health is 'Healthy'"
echo "  [ ] No 'unknown field' warnings in events"
echo "  [ ] test-argocd.yml workflow passes all tests"
echo "  [ ] Frontend/Grafana routes are accessible"
echo "  [ ] Helm status shows 'deployed'"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "🎉 Deployment Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Your OpenTelemetry Demo is now running with:"
echo "  ✅ Helm direct deployment (10m timeout)"
echo "  ✅ ArgoCD GitOps management"
echo "  ✅ Automatic sync and self-healing"
echo "  ✅ Comprehensive test coverage"
echo ""
echo "For monitoring and advanced configuration, see the"
echo "documentation files in your repository root."
echo ""
