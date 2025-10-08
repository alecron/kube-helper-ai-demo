{
  writeShellApplication,
  helmfile,
  kubernetes-helm,
  util-linux,
  kubectl,
}:
writeShellApplication {
  name = "deploy";
  runtimeInputs = [
    util-linux
    helmfile
    kubernetes-helm
    kubectl
  ];
  text = ''
    # The actual source directory (not Nix store)
    REPO_ROOT="${./.}"

    # Initialize k8s resources first (before helmfile)
    echo "📋 Initializing k8s resources from $REPO_ROOT..."
    cd "$REPO_ROOT"
    bash ./init-k8s-resources.sh

    # Deploy with helmfile, passing the real source directory
    echo "🚀 Deploying with helmfile..."
    cd "$REPO_ROOT"
    helmfile sync -f ./helmfile.yaml.gotmpl

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
