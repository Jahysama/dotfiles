{ pkgs, inputs, lib, vars }:

with lib;

let
  commonServiceAccountConfig = { create = true; };

  commonRbacConfig = {
    create = true;
    clusterRole = true;
    rules = [
      {
        apiGroups = [ "" ];
        resources = [ "services" "endpoints" "pods" ];
        verbs = [ "get" "watch" "list" ];
      }
      {
        apiGroups = [ "extensions" "networking.k8s.io" ];
        resources = [ "ingresses" ];
        verbs = [ "get" "watch" "list" ];
      }
      {
        apiGroups = [ "" ];
        resources = [ "nodes" ];
        verbs = [ "list" "watch" ];
      }
    ];
  };

  # Base configuration for all ExternalDNS instances
  externalDnsBase = {
    deploymentStrategy = { type = "Recreate"; };
    securityContext = { fsGroup = 65534; };
    sources = [ "service" "ingress" ];
    policy = "upsert-only";
    logLevel = "debug";
  };

  # Pi-hole specific configuration WITHOUT password authentication
  externalDnsPiholeConfig = overlayValues externalDnsBase {
    provider = "pihole";
    registry = "noop";
    serviceAccount = commonServiceAccountConfig // {
      name = "external-dns-pihole";
    };
    rbac = commonRbacConfig;
    env = [{
      name = "EXTERNAL_DNS_PIHOLE_SERVER";
      value = "http://${vars.piholeIp}";
    }
    # No EXTERNAL_DNS_PIHOLE_PASSWORD needed when Pi-hole has no auth
      ];
    args = [
      "--source=service"
      "--source=ingress"
      "--provider=pihole"
      "--registry=noop"
      "--policy=upsert-only"
      "--log-level=debug"
    ];
    extraArgs = [
      "--pihole-tls-skip-verify"
      "--txt-owner-id=k8s"
      "--pihole-api-version=6"
    ];
  };

  # Cloudflare specific configuration (unchanged)
  externalDnsCloudflareConfig = overlayValues externalDnsBase {
    provider = "cloudflare";
    registry = "txt";
    txtOwnerId = vars.domain;
    domainFilters = [ vars.domain ];
    cloudflare = { proxied = true; };
    serviceAccount = commonServiceAccountConfig // {
      name = "external-dns-cloudflare";
    };
    rbac = commonRbacConfig;
    env = [{
      name = "CF_API_TOKEN";
      valueFrom = {
        secretKeyRef = {
          name = "cloudflare-api-token";
          key = "api-token";
        };
      };
    }];
    # These domains are managed by the DDNS CronJob (point to public IP).
    # Excluding them prevents ExternalDNS from overwriting with the nginx
    # LAN IP (192.168.1.193), which is unreachable from the internet.
    extraArgs = [
      "--exclude-domains=signal.${vars.domain}"
      "--exclude-domains=nextcloud.${vars.domain}"
      "--exclude-domains=telegram.${vars.domain}"
    ];
  };

in {
  # ExternalDNS for automatic DNS registration with Pi-hole (no auth)
  externaldns-pihole = mkChart {
    name = "externaldns-pihole";
    chart = nixhelm.external-dns.external-dns;
    namespace = vars.namespaces.dns;
    values = externalDnsPiholeConfig;
  };

  # External DNS for Cloudflare integration (unchanged)
  externaldns-cloudflare = mkChart {
    name = "externaldns-cloudflare";
    chart = nixhelm.external-dns.external-dns;
    namespace = vars.namespaces.dns;
    values = externalDnsCloudflareConfig;
  };

  # Remove the pihole-password-dns secret since it's no longer needed
  # pihole-password-dns = mkSecretRef { ... };  # Comment out or remove this
}
