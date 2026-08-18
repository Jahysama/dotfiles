{ lib, config, ... }:

with lib;
let cfg = config.modules.wireguard;
in {
  options.modules.wireguard = {
    enable = mkEnableOption "wireguard";
  };

  config = mkIf cfg.enable {
    networking.wg-quick.interfaces.japan = {
      configFile = config.sops.secrets.japan_wg_private_key.path;
    };
  };
}
