{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.steam;

in {
    options.modules.steam = {
        enable = mkEnableOption "steam";
    };
    
    config = mkIf cfg.enable {
        # Move all these settings to the root config level, not under modules.steam
        programs.gamemode.enable = true;
        
        hardware = {
            bluetooth.enable = true;
            graphics = {
                enable = true;
                enable32Bit = true;
            };
        };
        
        environment.systemPackages = with pkgs; [
            protonup-qt
            winetricks
            protontricks
            azahar
            wineWowPackages.staging
        ];

        programs.steam = {
            enable = true;
            gamescopeSession.enable = true;
            extraCompatPackages = [ pkgs.proton-ge-bin ];
            package = pkgs.steam.override {
                extraPkgs = pkgs: with pkgs; [
                    freetype
                    libxcursor
                    libxi
                    libxinerama
                    libxscrnsaver
                    libpng
                    libpulseaudio
                    libvorbis
                    source-sans
                    source-serif
                    source-han-sans
                    source-han-serif
                    pipewire
                    udev
                    alsa-lib
                    vulkan-loader
                    libx11
                    libxcursor
                    libxi
                    libxrandr
                    libxkbcommon
                    wayland
                    mesa
                    libglvnd
                ];
            };
        };
    };
}
