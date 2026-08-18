{
  pkgs,
  lib,
  config,
  username,
  ...
}:

with lib;
let
  cfg = config.modules.sops;
in
{
  options.modules.sops = {
    enable = mkEnableOption "sops";
  };

  config = mkIf cfg.enable {
    sops = {
      age.keyFile = "/persist/etc/sops-nix/keys.txt";
      defaultSopsFile = ./secrets.yaml;
      defaultSopsFormat = "yaml";
      secrets = {
        antropic_key = {
          owner = "${username}";
        };
        spotify_client_id = {
          owner = "${username}";
        };
        github_token = {
          owner = "${username}";
        };
        git_email = {
          owner = "${username}";
        };
        cloudflare_email = {
          owner = "${username}";
        };
        k3s_token = {
          owner = "${username}";
        };
        pihole_password = {
          owner = "${username}";
        };
        cloudflare_token = {
          owner = "${username}";
        };

        # WireGuard server secrets
        wireguard_server_private_key = {
          owner = "root";
          mode = "0644";
        };
        wireguard_server_public_key = {
          owner = "root";
          mode = "0644";
        };
        wireguard_server_endpoint = {
          owner = "root";
          mode = "0644";
        };

        # WireGuard user secrets
        egor_main_wg_public_key = {
          owner = "root";
          mode = "0644";
        };
        egor_main_wg_private_key = {
          owner = "${username}";
          mode = "0600";
        };

        dsh_wg_public_key = {
          owner = "root";
          mode = "0644";
        };
        dsh_wg_private_key = {
          owner = "${username}";
          mode = "0600";
        };

        # Nextcloud secrets
        nextcloud_admin_password = {
          owner = "root";
          mode = "0644";
        };
        nextcloud_admin_username = {
          owner = "root";
          mode = "0644";
        };
        nextcloud_db_password = {
          owner = "root";
          mode = "0644";
        };
        nextcloud_db_username = {
          owner = "root";
          mode = "0644";
        };
        nextcloud_redis_password = {
          owner = "root";
          mode = "0644";
        };

        japan_wg_private_key = {
          owner = "root";
          mode = "0600";
        };

        user_password = {
          neededForUsers = true;
        };

        private_ssh_key = {
          path = "/home/${username}/.ssh/ssh_host_ed25519_key";
          mode = "0600";
          owner = "${username}";
        };

        gpg_private_key = {
          mode = "0400";
          owner = "${username}";
        };

        cv_tui_ssh_host_key = {
          path  = "/run/secrets/cv_ssh_host_key";
          owner = "root";
          mode  = "0600";
        };
      };
    };
  };
}
