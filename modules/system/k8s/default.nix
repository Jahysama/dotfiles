{ config, lib, pkgs, inputs, ... }:

with lib;
let
  cfg = config.modules.k8s;
  charts = import ./charts.nix { inherit pkgs inputs config; };

  nextcloudSsoScript = import ./scripts/nextcloud-sso.nix { inherit pkgs; };

  # Filter charts to get only secret references
  secretRefs = filterAttrs (_: chart: chart.isSecret) charts;

  # Filter charts to get regular (non-secret) charts
  regularCharts = filterAttrs (_: chart: !chart.isSecret) charts;

  # Define deployment groups with dependencies and order
  deploymentGroups = [
    {
      name = "core-infrastructure";
      charts = [ "longhorn" "metallb" ];
      waitFor = {
        metallb = {
          kind = "deployment";
          name = "metallb-controller";
          namespace = "metallb-system";
          timeout = 120;
        };
        longhorn = {
          kind = "deployment";
          name = "longhorn-driver-deployer";
          namespace = "longhorn-system";
          timeout = 180;
        };
      };
    }
    {
      name = "core-config";
      charts = [ "metallb-config" ];
      dependsOn = [ "core-infrastructure" ];
      retryAttempts = 5;
      retryDelay = 30;
    }
    {
      name = "networking-services";
      charts = [ "ingress-nginx" "pihole" ];
      dependsOn = [ "core-config" ];
      waitFor = {
        nginx = {
          kind = "deployment";
          name = "ingress-nginx-controller"; # Updated name
          namespace = "nginx-system";
          timeout = 180;
        };
      };
    }
    {
      name = "dns-services";
      charts = [ "externaldns-pihole" ];
      dependsOn = [ "networking-services" ];
      waitFor = {
        externaldns = {
          kind = "deployment";
          name = "external-dns";
          namespace = "pihole-system";
          timeout = 120;
        };
      };
    }
    {
      name = "external-access";
      # Changed: Remove external nginx, only cert-manager now
      charts = [ "cert-manager" ];
      dependsOn = [ "core-config" ];
      waitFor = {
        certmanager = {
          kind = "deployment";
          name = "cert-manager";
          namespace = "cert-manager";
          timeout = 180;
        };
      };
    }
    {
      name = "external-dns";
      charts = [ "externaldns-cloudflare" "cert-manager-issuers" "cloudflare-ddns" ];
      dependsOn = [ "external-access" ];
      waitFor = {
        externaldns = {
          kind = "deployment";
          name = "external-dns";
          namespace = "external-dns";
          timeout = 120;
        };
      };
    }
    {
      name = "external-ingress";
      charts = [ "pihole-external-ingress" ];
      dependsOn = [ "external-dns" "networking-services" ];
    }
    {
      name = "vpn-services";
      charts = [
        "wireguard-config"
        "wireguard-caddy-cert"
        "wireguard-storage"
        "wireguard-deployment"
        "wireguard-service"
      ];
      dependsOn = [ "core-config" "external-access" ];
      waitFor = {
        wireguard = {
          kind = "deployment";
          name = "wireguard";
          namespace = "wireguard-system";
          timeout = 120;
        };
      };
    }
    {
      name = "apps";
      charts = [ "signal-proxy" "telegram-proxy" "nextcloud" "cv" "cv-tui" "sslh" ];
      dependsOn = [ "core-config" "networking-services" "external-access" ];
      waitFor = {
        signal-proxy = {
          kind = "deployment";
          name = "signal-proxy";
          namespace = "proxies";
          timeout = 120;
        };
        telegram-proxy = {
          kind = "deployment";
          name = "telegram-proxy";
          namespace = "proxies";
          timeout = 120;
        };
        nextcloud = {
          kind = "deployment";
          name = "nextcloud";
          namespace = "nextcloud";
          timeout = 300;
        };
        cv = {
          kind = "deployment";
          name = "cv";
          namespace = "cv";
          timeout = 120;
        };
        cv-tui = {
          kind = "deployment";
          name = "cv-tui";
          namespace = "cv";
          timeout = 60;
        };
        sslh = {
          kind = "deployment";
          name = "sslh";
          namespace = "cv";
          timeout = 60;
        };
      };
    }
  ];

  requiredNamespaces =
    unique (mapAttrsToList (_: chart: chart.namespace) charts);

  # Generate the deployment script for a group
  generateDeployScript = group: ''
    echo "Deploying group: ${group.name}"

    ${optionalString (group ? dependsOn) ''
      # Check if dependent groups completed successfully
      ${concatMapStringsSep "\n" (dep: ''
        if [ ! -f "/var/lib/kubernetes/.deploy-${dep}-done" ]; then
          echo "Dependent group ${dep} has not completed successfully. Aborting."
          exit 1
        fi
      '') group.dependsOn}
    ''}
    ${concatMapStringsSep "\n" (chartName: ''
      echo "Deploying ${chartName} to namespace ${
        regularCharts.${chartName}.namespace
      }..."
      retries=${toString (group.retryAttempts or 3)}
      delay=${toString (group.retryDelay or 10)}
      success=false
      for i in $(seq 1 $retries); do
        echo "Attempt $i of $retries for ${chartName}..."
        # Add the -n flag with the namespace
        if kubectl apply -f /var/lib/kubernetes/manifests/${chartName}.yaml --validate=false -n ${
          regularCharts.${chartName}.namespace
        }; then
          success=true
          break
        else
          echo "Failed to deploy ${chartName}, waiting $delay seconds before retry..."
          sleep $delay
        fi
      done
      if [ "$success" != "true" ]; then
        echo "Failed to deploy ${chartName} after $retries attempts"
        exit 1
      fi
    '') group.charts}

    # Wait for resources if specified
    ${optionalString (group ? waitFor) (concatStringsSep "\n" (mapAttrsToList
      (resourceName: resource: ''
        echo "Waiting for ${resource.kind} ${resource.name} in namespace ${resource.namespace} to be ready..."

        ${if (resource.kind == "deployment" || resource.kind == "Deployment") then ''
          kubectl rollout status deployment/${resource.name} -n ${resource.namespace} --timeout=${
            toString (resource.timeout or 120)
          }s || {
            echo "Rollout of deployment/${resource.name} did not complete in time"
            echo "WARNING: Resource not ready, but continuing..."
          }
        '' else ''
          kubectl wait --for=condition=Available --timeout=${
            toString (resource.timeout or 120)
          }s ${resource.kind}/${resource.name} -n ${resource.namespace} || {
            echo "Timed out waiting for ${resource.kind}/${resource.name} to be ready"
            echo "WARNING: Resource not ready, but continuing..."
          }
        ''}
      '') group.waitFor))}

    # Mark this group as done
    touch /var/lib/kubernetes/.deploy-${group.name}-done
    echo "Group ${group.name} completed successfully"
  '';
in {
  options.modules.k8s = { enable = mkEnableOption "k8s"; };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ kubectl kubernetes-helm ];

    # Create manifest directory and prepare for redeployment
    system.activationScripts.kubernetes-prepare = {
      text = ''
        mkdir -p /var/lib/kubernetes/manifests

        # Create a simple sentinel file to track when charts are copied
        echo "${
          builtins.toString
          (mapAttrsToList (name: chart: chart.path) regularCharts)
        }" > /var/lib/kubernetes/.chart-paths

        # Copy charts 
        ${concatStringsSep "\n" (mapAttrsToList (name: chart: ''
          echo "Copying ${name} chart..."
          cp ${chart.path} /var/lib/kubernetes/manifests/${name}.yaml
        '') regularCharts)}

        # Clear deployment markers for groups containing modified charts
        ${concatStringsSep "\n" (map (group:
          let groupCharts = concatStringsSep "\\|" group.charts;
          in ''
            # Check if any charts in this group were modified
            for chart in ${concatStringsSep " " group.charts}; do
              if [ -z "$modified_groups" ] || ! echo "$modified_groups" | grep -q "${group.name}"; then
                echo "Clearing markers for group ${group.name} and dependencies"
                rm -f /var/lib/kubernetes/.deploy-${group.name}-done
                modified_groups="${group.name} $modified_groups"
                ${
                  optionalString (group ? dependsOn) (concatMapStringsSep "\n"
                    (dep: ''
                      if [ -z "$modified_deps" ] || ! echo "$modified_deps" | grep -q "${dep}"; then
                        echo "Group ${group.name} depends on ${dep}, clearing its marker"
                        rm -f /var/lib/kubernetes/.deploy-${dep}-done
                        modified_deps="${dep} $modified_deps"
                      fi
                    '') group.dependsOn)
                }
                break
              fi
            done
          '') deploymentGroups)}

        # Always attempt to restart k8s-deploy
        if command -v systemctl >/dev/null 2>&1; then
          echo "Triggering k8s-deploy service"
          systemctl stop k8s-deploy 2>/dev/null || true
          systemctl start k8s-deploy 2>/dev/null || true
        else
          echo "systemctl not available, deployment will be handled at next boot"
        fi
      '';
      deps = [ "specialfs" "users" "groups" ];
    };

    # Deployment service
    systemd.services.k8s-deploy = {
      description = "Deploy Kubernetes resources";
      after = [ "k3s.service" ];
      wants = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ kubectl coreutils bash ];

      # This will cause the script to be regenerated every time the path to any chart changes
      # (which happens when chart content changes)
      restartTriggers = [
        (builtins.hashString "sha256" (builtins.toString
          (mapAttrsToList (name: chart: chart.path) regularCharts)))
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "k8s-deploy" ''
          # Wait for k3s API to be ready
          echo "Waiting for Kubernetes API to be ready..."
          KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          export KUBECONFIG

          count=0
          max_attempts=30
          until kubectl get nodes &>/dev/null; do
            echo "Waiting for Kubernetes API... Attempt $count of $max_attempts"
            sleep 10
            count=$((count + 1))
            if [ $count -ge $max_attempts ]; then
              echo "Kubernetes API did not become available in time"
              exit 1
            fi
          done

          # Create required namespaces first
          echo "Creating namespaces: ${
            concatStringsSep ", " requiredNamespaces
          }"
          ${concatMapStringsSep "\n" (ns: ''
            kubectl get namespace ${ns} &>/dev/null || kubectl create namespace ${ns}
          '') requiredNamespaces}

          echo "Cleaning up all existing jobs..."
          kubectl delete jobs --all --all-namespaces --ignore-not-found=true
          # Wait a moment for cleanup to complete
          sleep 5

          # Create secrets first from SOPS
          ${concatStringsSep "\n" (mapAttrsToList (name: secretRef: ''
            echo "Creating secret ${secretRef.secretName} in namespace ${secretRef.namespace}..."
            # Read the secret value directly from SOPS
            SECRET_VALUE=$(cat ${
              config.sops.secrets.${secretRef.sopsSecretName}.path
            })

            # Ensure the secret exists, then patch-merge the key in.
            # Using patch --type=merge lets multiple mkSecretRef entries targeting
            # the same secret each contribute their own key without clobbering others.
            kubectl get secret "${secretRef.secretName}" -n "${secretRef.namespace}" &>/dev/null \
              || kubectl create secret generic "${secretRef.secretName}" -n "${secretRef.namespace}"
            SECRET_B64=$(printf '%s' "$SECRET_VALUE" | base64 -w0)
            kubectl patch secret "${secretRef.secretName}" -n "${secretRef.namespace}" \
              --type=merge -p "{\"data\":{\"${secretRef.secretKey}\":\"$SECRET_B64\"}}"
          '') secretRefs)}

          # Give a moment for the secrets to be fully stored
          sleep 5

          # Deploy each group in sequence
          ${concatMapStringsSep "\n\n" generateDeployScript deploymentGroups}

          ${nextcloudSsoScript}/bin/nextcloud-sso

          echo "All deployments completed successfully!"
        ''}";
      };
    };
  };
}
