{ ... }: {
  imports = [ ../../modules/system/configuration.nix ];

  config = {
    diskConfig = {
      device = "/dev/nvme0n1";
      espSize = "500M";
    };
    modules = {
      sys-packages.enable = true;
      steam.enable = true;
      stylix.enable = true;
      # unifi.enable = true;
      sops.enable = true;
      desktop.enable = true;
      wireguard.enable = true;
    };
  };
}
