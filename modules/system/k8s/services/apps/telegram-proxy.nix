{ pkgs, inputs, lib, vars }:

let
  namespace = vars.namespaces.proxies;

  deploymentResource = {
    apiVersion = "apps/v1";
    kind = "Deployment";
    metadata = {
      name = "telegram-proxy";
      inherit namespace;
    };
    spec = {
      replicas = 1;
      selector.matchLabels.app = "telegram-proxy";
      template = {
        metadata.labels.app = "telegram-proxy";
        spec = {
          containers = [{
            name = "telegram-proxy";
            # Erlang-based MTProto proxy — handles thousands of concurrent connections.
            # Fake-TLS mode (MTP_TLS_ONLY=1) makes traffic look like a TLS ClientHello,
            # which lets it go through nginx ssl-passthrough (same path as signal-proxy).
            image = "seriyps/mtproto-proxy:latest";
            ports = [{
              name = "mtproto";
              containerPort = 443;
              protocol = "TCP";
            }];
            env = [
              { name = "MTP_PORT";     value = "443"; }
              { name = "MTP_TLS_ONLY"; value = "1"; }
              {
                name = "MTP_SECRET";
                valueFrom.secretKeyRef = {
                  name = "telegram-proxy-secrets";
                  key  = "secret";
                };
              }
            ];
            resources = {
              requests = { cpu = "10m";  memory = "32Mi";  };
              limits   = { cpu = "200m"; memory = "128Mi"; };
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
      name = "telegram-proxy";
      inherit namespace;
    };
    spec = {
      type = "ClusterIP";
      selector.app = "telegram-proxy";
      ports = [{
        name       = "mtproto";
        port       = 443;
        targetPort = 443;
        protocol   = "TCP";
      }];
    };
  };

  # nginx reads the SNI from the fake-TLS ClientHello and routes to this pod.
  # The proxy handles the full fake-TLS handshake itself — no cert needed here.
  ingressResource = {
    apiVersion = "networking.k8s.io/v1";
    kind = "Ingress";
    metadata = {
      name = "telegram-proxy";
      inherit namespace;
      annotations = {
        "nginx.ingress.kubernetes.io/ssl-passthrough" = "true";
      };
    };
    spec = {
      ingressClassName = "nginx";
      rules = [{
        host = "telegram.${vars.domain}";
        http.paths = [{
          path     = "/";
          pathType = "Prefix";
          backend.service = {
            name = "telegram-proxy";
            port.number = 443;
          };
        }];
      }];
    };
  };
in {
  telegram-proxy = lib.mkRawManifest {
    name      = "telegram-proxy";
    inherit namespace;
    resources = [ deploymentResource serviceResource ingressResource ];
  };

  telegram-proxy-secret = lib.mkSecretRef {
    name           = "telegram-proxy-secret";
    inherit namespace;
    secretName     = "telegram-proxy-secrets";
    secretKey      = "secret";
    sopsSecretName = "telegram_proxy_secret";
  };
}
