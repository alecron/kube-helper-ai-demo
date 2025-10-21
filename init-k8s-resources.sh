#!/usr/bin/env bash
set -euo pipefail

# This script initializes k8s resources before helmfile runs
# It should be run from the kube-helper-ai-demo directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🏗️  Working from: $SCRIPT_DIR"

echo "🏗️  Creating namespaces..."
kubectl create namespace mcpo --dry-run=client -o yaml | kubectl apply -f -

echo "📋 Deploying namespaces and secrets..."
kubectl apply -f k8s/playground-namespace.yaml
kubectl apply -f k8s/production-secrets.yaml

echo "📦 Creating ConfigMaps for MCPO..."
# Create ConfigMap from setup script
kubectl create configmap setup-exploits-script \
  --from-file=setup-exploits.sh=k8s/setup-exploits.sh \
  --namespace=mcpo \
  --dry-run=client -o yaml | kubectl apply -f -

# Create ConfigMap from MCP servers directory
kubectl create configmap mcp-servers-code \
  --from-file=mcp-servers/ \
  --namespace=mcpo \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🚀 Deploying workshop resources..."
kubectl apply -f k8s/mcpo-deployment.yaml
kubectl apply -f k8s/mcpo-rbac.yaml

echo "✅ K8s resources initialized successfully"
