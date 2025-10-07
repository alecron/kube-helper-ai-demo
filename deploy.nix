{
  writeShellApplication,
  helmfile,
  kubernetes-helm,
  util-linux,
  docker,
  kubectl,
}:
writeShellApplication {
  name = "deploy";
  runtimeInputs = [
    util-linux
    helmfile
    kubernetes-helm
    docker
    kubectl
  ];
  text = ''
    # Build MCPO image
    echo "🐳 Building MCPO image..."
    cd ${./.}

    IMAGE_NAME="workshop/mcpo"
    IMAGE_TAG="latest"

    docker build \
      -t "$IMAGE_NAME:$IMAGE_TAG" \
      -f mcpo.Dockerfile \
      .

    # Deploy in-cluster registry
    echo "📦 Deploying in-cluster Docker registry..."
    kubectl create namespace registry --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Pod
    metadata:
      name: registry
      namespace: registry
      labels:
        app: registry
    spec:
      containers:
      - name: registry
        image: registry:2
        ports:
        - containerPort: 5000
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: registry
      namespace: registry
    spec:
      selector:
        app: registry
      ports:
      - port: 5000
        targetPort: 5000
    EOF

    # Wait for registry to be ready
    echo "⏳ Waiting for registry..."
    kubectl wait --for=condition=ready pod/registry -n registry --timeout=120s

    # Port-forward to registry and push image
    echo "📤 Pushing image to in-cluster registry..."
    kubectl port-forward -n registry pod/registry 5000:5000 &
    PF_PID=$!
    sleep 3

    docker tag "$IMAGE_NAME:$IMAGE_TAG" "localhost:5000/$IMAGE_NAME:$IMAGE_TAG"
    docker push "localhost:5000/$IMAGE_NAME:$IMAGE_TAG"

    kill $PF_PID 2>/dev/null || true

    # Update deployment to use in-cluster registry
    sed -i.bak "s|ghcr.io/workshop/mcpo:latest|registry.registry.svc.cluster.local:5000/$IMAGE_NAME:$IMAGE_TAG|g" k8s/mcpo-deployment.yaml

    echo "🚀 Deploying with helmfile..."
    helmfile sync -f ${./helmfile.yaml.gotmpl}

    # Restore original deployment
    mv k8s/mcpo-deployment.yaml.bak k8s/mcpo-deployment.yaml 2>/dev/null || true

    function update_open_webui_ingress_hostname() {
      NAMESPACE="open-webui"
      INGRESS_NAME="open-webui"
      LB_NAMESPACE="ingress-nginx"
      LB_SERVICE="ingress-nginx-controller"

      # Wait for LoadBalancer IP
      echo "Waiting for LoadBalancer IP from $LB_SERVICE..."
      while true; do
        IP=$(kubectl get svc $LB_SERVICE -n $LB_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [[ -n "$IP" ]]; then
          echo "Found IP: $IP"
          break
        fi
        sleep 2
      done

      NEW_HOST="$(uuidgen).$IP.nip.io"
      echo "Patching ingress host to $NEW_HOST..."

      kubectl patch ingress $INGRESS_NAME -n $NAMESPACE \
        --type='json' \
        -p="[{\"op\": \"replace\", \"path\": \"/spec/rules/0/host\", \"value\": \"$NEW_HOST\"}]"

      echo "Done!"
    }

    update_open_webui_ingress_hostname
  '';
}
