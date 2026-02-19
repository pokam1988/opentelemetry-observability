#!/bin/bash
# Script to cleanup old Helm releases before deploying new configuration
# Usage: ./scripts/cleanup-releases.sh <namespace>

set -e

NAMESPACE="${1:-pokamr-dev}"

echo "═══════════════════════════════════════════════════════════════"
echo "🧹 Cleaning up old Helm releases"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Namespace: $NAMESPACE"
echo ""

# Check if namespace exists
if ! oc get namespace "$NAMESPACE" &> /dev/null; then
  echo "❌ Namespace '$NAMESPACE' does not exist"
  exit 1
fi

# List of releases to uninstall (old individual releases)
RELEASES_TO_REMOVE=(
  "grafana"
  "tempo"
  "prometheus"
  "loki"
  "jaeger"
  "opensearch"
  "otel-collector-backend"
  "otel-collector-gateway"
  "blackbox-exporter"
  "prometheus-operator"
  "grafana-dashboards-cm"
  "grafana-init"
)

echo "📋 Current Helm releases in namespace '$NAMESPACE':"
echo "───────────────────────────────────────────────────────────────"
helm list -n "$NAMESPACE" || echo "No releases found"
echo ""

echo "🗑️  Attempting to remove old releases..."
echo "───────────────────────────────────────────────────────────────"

REMOVED=0
SKIPPED=0

for release in "${RELEASES_TO_REMOVE[@]}"; do
  if helm list -n "$NAMESPACE" | grep -q "^$release[[:space:]]"; then
    echo "🗑️  Removing release: $release"
    if helm uninstall "$release" -n "$NAMESPACE" --wait 2>/dev/null; then
      echo "   ✅ Successfully uninstalled: $release"
      ((REMOVED++))
    else
      echo "   ⚠️  Failed to uninstall: $release (continuing...)"
    fi
  else
    echo "⏭️  Release not found: $release (skipping)"
    ((SKIPPED++))
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📊 Cleanup Summary"
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Removed: $REMOVED releases"
echo "⏭️  Skipped: $SKIPPED releases"
echo ""

echo "📋 Remaining Helm releases in namespace '$NAMESPACE':"
echo "───────────────────────────────────────────────────────────────"
helm list -n "$NAMESPACE" || echo "No releases found"
echo ""

echo "✨ Cleanup completed! Ready to deploy new configuration."
echo ""
echo "🚀 Next steps:"
echo "   helm upgrade --install otel-demo ./charts/opentelemetry-demo \\"
echo "     --namespace $NAMESPACE \\"
echo "     -f ./charts/opentelemetry-demo/ocp-values.yaml \\"
echo "     --wait --timeout=10m"
