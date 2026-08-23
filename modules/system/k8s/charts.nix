{ pkgs, inputs, config ? null, ... }:

let
  # Import lib.nix for helper functions but not variables
  lib = import ./lib.nix { inherit pkgs inputs; };

  # Centralized variables for all services
  vars = rec {
    domain = "egor.house";

    # Namespace definitions
    namespaces = {
      dns = "dns-system";
      pihole = "pihole-system";
      nginx = "nginx-system";
      metallb = "metallb-system";
      longhorn = "longhorn-system";
      monitoring = "monitoring-system";
      wireguard = "wireguard-system";
      proxies   = "proxies";
      nextcloud = "nextcloud";
      cv = "cv";
    };

    # IP address pools
    ipPools = {
      metallb = "192.168.1.192/26";
      nginxExternal = "192.168.1.193";
      pihole = "192.168.1.250";
      wireguard = "192.168.1.194";
      sslh      = "192.168.1.195";
    };

    # References to make code cleaner
    piholeIp = ipPools.pihole;

    # Version control for images
    versions = { pihole = "2025.11.1"; };

    # Common configuration
    defaultReplicas = 1;

    # TLS configuration
    tls = {
      defaultIssuer = "letsencrypt-prod";
      stagingIssuer = "letsencrypt-staging";
      acmeServerProduction = "https://acme-v02.api.letsencrypt.org/directory";
      acmeServerStaging =
        "https://acme-staging-v02.api.letsencrypt.org/directory";
    };
  };

  coreServices = {
    longhorn =
      import ./services/core/longhorn.nix { inherit pkgs inputs lib vars; };
    metallb =
      import ./services/core/metallb.nix { inherit pkgs inputs lib vars; };
    nginx = import ./services/core/nginx.nix { inherit pkgs inputs lib vars; };
  };

  dnsServices = {
    pihole = import ./services/dns/pihole.nix { inherit pkgs inputs lib vars; };
    externaldns =
      import ./services/dns/externaldns.nix { inherit pkgs inputs lib vars; };
    certManager =
      import ./services/dns/cert-manager.nix { inherit pkgs inputs lib vars; };
    ddns = import ./services/dns/ddns.nix { inherit pkgs inputs lib vars; };
  };

  ingressResources = {
    ingress =
      import ./services/ingress/ingress.nix { inherit pkgs inputs lib vars; };
  };

  vpnServices = {
    wireguard = import ./services/vpn/wireguard.nix {
      inherit pkgs inputs lib vars config;
    };
  };

  appServices = {
    signalProxy   = import ./services/apps/signal-proxy.nix    { inherit pkgs inputs lib vars; };
    telegramProxy = import ./services/apps/telegram-proxy.nix { inherit pkgs inputs lib vars; };
    nextcloud     = import ./services/apps/nextcloud.nix       { inherit pkgs inputs lib vars; };
    cv          = import ./services/apps/cv.nix           { inherit pkgs inputs lib vars; };
    cvTui       = import ./services/apps/cv-tui.nix       { inherit pkgs inputs lib vars; };
    sslh        = import ./services/apps/sslh.nix         { inherit pkgs inputs lib vars; };
  };

  # Create a list of all service attribute sets
  services = builtins.concatLists (map builtins.attrValues [
    coreServices
    dnsServices
    ingressResources
    vpnServices
    appServices
  ]);

  # Combine them all with a single fold operation
  allServices = lib.recursiveMerge' services;

in allServices
