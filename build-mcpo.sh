#!/usr/bin/env bash
set -euo pipefail

# Build the MCPO Docker image with workshop customizations
# This includes the custom MCP shell server and exploitable files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE_NAME="${IMAGE_NAME:-ghcr.io/workshop/mcpo}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "🐳 Building MCPO image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

docker build \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  -f mcpo.Dockerfile \
  .

echo ""
echo "✅ Image built successfully: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "Next steps:"
echo "  • Push to registry: docker push ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  • Or load into kind: kind load docker-image ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  • Or use with minikube: minikube image load ${IMAGE_NAME}:${IMAGE_TAG}"
