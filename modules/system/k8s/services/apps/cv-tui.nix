{ pkgs, inputs, lib, vars }:

let
  namespace = vars.namespaces.cv;

  deploymentResource = {
    apiVersion = "apps/v1";
    kind = "Deployment";
    metadata = {
      name = "cv-tui";
      inherit namespace;
    };
    spec = {
      replicas = 1;
      selector.matchLabels.app = "cv-tui";
      template = {
        metadata.labels.app = "cv-tui";
        spec = {
          nodeName = "meowth";
          containers = [{
            name = "cv-tui";
            image = "docker.io/thatbagu/cv-tui:latest";
            imagePullPolicy = "Always";
            ports = [{
              name = "ssh";
              containerPort = 2222;
              protocol = "TCP";
            }];
            volumeMounts = [{
              name = "ssh-host-key";
              mountPath = "/app/.ssh/cv_ssh_host_key";
              readOnly = true;
            }];
            resources = {
              requests = { cpu = "50m"; memory = "64Mi"; };
              limits   = { cpu = "200m"; memory = "256Mi"; };
            };
          }];
          volumes = [{
            name = "ssh-host-key";
            hostPath = {
              path = "/run/secrets/cv_ssh_host_key";
              type = "File";
            };
          }];
        };
      };
    };
  };

  serviceResource = {
    apiVersion = "v1";
    kind = "Service";
    metadata = {
      name = "cv-tui";
      inherit namespace;
    };
    spec = {
      type           = "LoadBalancer";
      loadBalancerIP = vars.ipPools.sslh;
      externalTrafficPolicy = "Cluster";
      selector.app   = "cv-tui";
      ports = [{
        name       = "ssh";
        port       = 22;
        targetPort = 2222;
        protocol   = "TCP";
      }];
    };
  };
in {
  cv-tui = lib.mkRawManifest {
    name      = "cv-tui";
    inherit namespace;
    resources = [ deploymentResource serviceResource ];
  };
}
