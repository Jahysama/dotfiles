{ pkgs, inputs, lib, vars }:

let
  # cert-manager issues a Let's Encrypt cert for signal.egor.house via DNS-01.
  # Signal app verifies this cert normally (CA chain), not via pinning —
  # pinning only applies to Signal's own servers, not user-configured proxies.
  certificateResource = {
    apiVersion = "cert-manager.io/v1";
    kind = "Certificate";
    metadata = {
      name = "signal-proxy-tls";
      namespace = vars.namespaces.proxies;
    };
    spec = {
      dnsNames = [ "signal.${vars.domain}" ];
      secretName = "signal-proxy-tls";
      issuerRef = {
        kind = "ClusterIssuer";
        name = vars.tls.defaultIssuer;
      };
    };
  };

  configMapResource = {
    apiVersion = "v1";
    kind = "ConfigMap";
    metadata = {
      name = "signal-proxy-config";
      namespace = vars.namespaces.proxies;
    };
    # Two-server architecture matching Signal's official proxy:
    # 1. Port 443: terminates outer TLS (presents signal.egor.house cert),
    #    forwards raw decrypted bytes to loopback port 4433.
    # 2. Port 4433: uses ssl_preread to read the INNER TLS ClientHello SNI
    #    that Signal sends as application data, then routes that inner TLS
    #    stream as-is to the correct Signal backend. No re-encryption —
    #    the inner TLS is a direct tunnel between Signal app and Signal servers.
    data."nginx.conf" = ''
      error_log /dev/stderr info;

      events {
        worker_connections 4096;
      }

      stream {
        log_format proxy '$remote_addr [$time_local] $protocol $status '
                         '$bytes_sent $bytes_received $session_time';
        access_log /dev/stdout proxy;

        resolver 1.1.1.1 8.8.8.8 valid=300s;
        resolver_timeout 10s;

        # Outer TLS termination — decrypts Signal's outer TLS layer.
        server {
          listen 443 ssl;
          ssl_certificate /etc/ssl/signal/tls.crt;
          ssl_certificate_key /etc/ssl/signal/tls.key;
          ssl_protocols TLSv1.2 TLSv1.3;
          proxy_pass 127.0.0.1:4433;
          proxy_connect_timeout 30s;
          proxy_timeout 600s;
        }

        # Route inner TLS by SNI to the correct Signal service.
        map $ssl_preread_server_name $signal_upstream {
          chat.signal.org          chat.signal.org:443;
          storage.signal.org       storage.signal.org:443;
          cdn.signal.org           cdn.signal.org:443;
          cdn2.signal.org          cdn2.signal.org:443;
          cdn3.signal.org          cdn3.signal.org:443;
          cdsi.signal.org          cdsi.signal.org:443;
          contentproxy.signal.org  contentproxy.signal.org:443;
          grpc.chat.signal.org     grpc.chat.signal.org:443;
          sfu.voip.signal.org      sfu.voip.signal.org:443;
          svr2.signal.org          svr2.signal.org:443;
          svrb.signal.org          svrb.signal.org:443;
          updates.signal.org       updates.signal.org:443;
          updates2.signal.org      updates2.signal.org:443;
          default                  127.0.0.1:9;
        }

        server {
          listen 4433;
          ssl_preread on;
          proxy_pass $signal_upstream;
          proxy_connect_timeout 30s;
          proxy_timeout 600s;
        }
      }
    '';
  };

  deploymentResource = {
    apiVersion = "apps/v1";
    kind = "Deployment";
    metadata = {
      name = "signal-proxy";
      namespace = vars.namespaces.proxies;
    };
    spec = {
      replicas = 1;
      selector.matchLabels.app = "signal-proxy";
      template = {
        metadata.labels.app = "signal-proxy";
        spec = {
          containers = [{
            name = "signal-proxy";
            image = "nginx:stable-alpine";
            ports = [{
              name = "tcp";
              containerPort = 443;
              protocol = "TCP";
            }];
            volumeMounts = [
              {
                name = "config";
                mountPath = "/etc/nginx/nginx.conf";
                subPath = "nginx.conf";
              }
              {
                name = "tls";
                mountPath = "/etc/ssl/signal";
                readOnly = true;
              }
            ];
            resources = {
              requests = { cpu = "10m"; memory = "16Mi"; };
              limits = { cpu = "100m"; memory = "64Mi"; };
            };
          }];
          volumes = [
            { name = "config"; configMap.name = "signal-proxy-config"; }
            { name = "tls"; secret.secretName = "signal-proxy-tls"; }
          ];
        };
      };
    };
  };

  # ClusterIP — external access goes through nginx ingress ssl-passthrough
  serviceResource = {
    apiVersion = "v1";
    kind = "Service";
    metadata = {
      name = "signal-proxy";
      namespace = vars.namespaces.proxies;
    };
    spec = {
      type = "ClusterIP";
      selector.app = "signal-proxy";
      ports = [{
        name = "tcp";
        port = 443;
        targetPort = 443;
        protocol = "TCP";
      }];
    };
  };

  # nginx ingress passes raw TLS stream to signal-proxy based on SNI.
  # No TLS termination here — signal-proxy handles the forwarding.
  ingressResource = {
    apiVersion = "networking.k8s.io/v1";
    kind = "Ingress";
    metadata = {
      name = "signal-proxy";
      namespace = vars.namespaces.proxies;
      annotations = {
        "nginx.ingress.kubernetes.io/ssl-passthrough" = "true";
      };
    };
    spec = {
      ingressClassName = "nginx";
      rules = [{
        host = "signal.${vars.domain}";
        http.paths = [{
          path = "/";
          pathType = "Prefix";
          backend.service = {
            name = "signal-proxy";
            port.number = 443;
          };
        }];
      }];
    };
  };
  hpaResource = {
    apiVersion = "autoscaling/v2";
    kind = "HorizontalPodAutoscaler";
    metadata = {
      name = "signal-proxy";
      namespace = vars.namespaces.proxies;
    };
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        name = "signal-proxy";
      };
      minReplicas = 1;
      maxReplicas = 5;
      metrics = [
        {
          type = "Resource";
          resource = {
            name = "memory";
            target = { type = "Utilization"; averageUtilization = 75; };
          };
        }
        {
          type = "Resource";
          resource = {
            name = "cpu";
            target = { type = "Utilization"; averageUtilization = 70; };
          };
        }
      ];
    };
  };
in {
  signal-proxy = lib.mkRawManifest {
    name = "signal-proxy";
    namespace = vars.namespaces.proxies;
    resources = [
      certificateResource
      configMapResource
      deploymentResource
      serviceResource
      ingressResource
      hpaResource
    ];
  };
}
