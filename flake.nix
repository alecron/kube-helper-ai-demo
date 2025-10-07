{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      overlays.default = final: pkgs: rec {
        helm-with-plugins = pkgs.wrapHelm pkgs.kubernetes-helm {
          # https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=kubernetes-helmPlugins
          plugins = with pkgs.kubernetes-helmPlugins; [
            helm-diff
          ];
        };

        helmfile-with-plugins = pkgs.helmfile-wrapped.override { inherit (helm-with-plugins) pluginsDir; };

        gdk = pkgs.google-cloud-sdk.withExtraComponents (
          with pkgs.google-cloud-sdk.components;
          [
            gke-gcloud-auth-plugin
          ]
        );
      };

      flake = flake-utils.lib.eachDefaultSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ self.overlays.default ];
          };
        in
        {
          packages = { };

          apps = {
            deploy = flake-utils.lib.mkApp { drv = pkgs.callPackage ./deploy.nix { }; };
          };

          devShells.default =
            with pkgs;
            mkShellNoCC {
              packages = [
                # Python development
                python3
                uv
                ruff

                # Python LSP for editors
                (python3.withPackages (
                  ps: with ps; [
                    jedi-language-server
                    python-lsp-server
                  ]
                ))

                # Kubernetes/Helm tools
                helm-with-plugins
                helmfile-with-plugins
                kubectl

                # Cloud tools
                gdk

                # Node.js for MCP servers
                nodejs_22
              ];

              shellHook = ''
                echo "🚀 Workshop Development Environment"
                echo "  • Python $(python --version | cut -d' ' -f2) with uv"
                echo "  • Helm $(helm version --short)"
                echo "  • kubectl $(kubectl version --client --short 2>/dev/null || echo 'not connected')"
                echo ""
                echo "📦 MCP Servers: ./mcp-servers/"
                echo "  Run: cd mcp-servers && uv pip install -e ."
              '';
            };

          formatter = pkgs.nixfmt-rfc-style;
        }
      );

    in
    flake // { inherit overlays; };
}
