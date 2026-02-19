#!/bin/bash
# Script to create OpenShift Routes for OpenTelemetry Demo services
# Usage: ./scripts/create-routes.sh <namespace> [environment]

set -e

NAMESPACE="${1:-pokamr-dev}"
ENVIRONMENT="${2:-dev}"

echo "═══════════════════════════════════════════════════════════════"
echo "🌐 Creating OpenShift Routes for OpenTelemetry Demo"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Namespace: $NAMESPACE"
echo "Environment: $ENVIRONMENT"
echo ""

# Check if namespace exists
if ! oc get namespace "$NAMESPACE" &> /dev/null; then
  echo "❌ Namespace '$NAMESPACE' does not exist"
  exit 1
fi

# Switch to namespace
oc project "$NAMESPACE"

# Define services to expose and their internal ports
declare -A SERVICES_PORTS=(
  ["frontend"]=8080
  ["frontend-proxy"]=8080
  ["grafana"]=80
  ["prometheus"]=9090
  ["jaeger-query"]=16686
  ["tempo"]=3200
  ["otel-collector"]=4317
)

echo "📋 Finding available services..."
echo ""

CREATED=0
SKIPPED=0
FAILED=0

for service in "${!SERVICES_PORTS[@]}"; do
  PORT="${SERVICES_PORTS[$service]}"
  
  # Check if service exists
  if ! oc get svc "$service" -n "$NAMESPACE" &> /dev/null; then
    echo "⏭️  Service '$service' not found - skipping"
    ((SKIPPED++))
    continue
  fi
  
  # Check if route already exists
  if oc get route "$service" -n "$NAMESPACE" &> /dev/null; then
    echo "✅ Route already exists for '$service'"
    ((SKIPPED++))
    continue
  fi
  
  # Get actual service port if different
  ACTUAL_PORT=$(oc get svc "$service" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "$PORT")
  
  echo "🔗 Creating route for '$service' (port: $ACTUAL_PORT)..."
  
  # Create route with edge TLS termination
  if oc expose svc "$service" \
    -n "$NAMESPACE" \
    --port="$ACTUAL_PORT" \
    --name="$service" 2>/dev/null; then
    
    # Configure TLS with edge termination and redirect HTTP to HTTPS
    oc patch route "$service" -n "$NAMESPACE" \
      -p '{"spec":{"tls":{"termination":"edge","insecureEdgeTerminationPolicy":"Redirect"}}}' \
      2>/dev/null || true
    
    ROUTE_HOST=$(oc get route "$service" -n "$NAMESPACE" -o jsonpath='{.spec.host}')
    echo "   ✅ Route created: https://$ROUTE_HOST"
    ((CREATED++))
  else
    echo "   ❌ Failed to create route for '$service'"
    ((FAILED++))
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📊 Summary"
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Created: $CREATED"
echo "⏭️  Skipped: $SKIPPED"
echo "❌ Failed: $FAILED"
echo ""

echo "🌐 All available routes:"
echo "───────────────────────────────────────────────────────────────"
oc get routes -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"  |  https://"}{.spec.host}{"\n"}{end}' || echo "No routes found"

echo ""
echo "✨ Route creation completed!"
echo ""
echo "🔐 Note: Routes are configured with edge TLS termination"
echo "   and automatic HTTP→HTTPS redirect"
