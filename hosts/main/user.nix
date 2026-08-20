{ ... }: {
  imports = [ ../../modules/home/default.nix ];
  config.modules = {
    # GUI Applications
    firefox.enable = true;
    foot.enable = true;
    dunst.enable = true;
    hyprland.enable = true;
    papertoy.enable = true;
    papertoy.shader = ../../pics/shapes.glsl;
    fuzzel.enable = true;
    waybar.enable = true;
    rtorrent.enable = true;
    swaylock.enable = true;

    # Terminal & Shell
    nixvim.enable = true;
    fish.enable = true;
    zellij.enable = true;
    k9s.enable = true;

    # Development
    git.enable = true;
    git.gpgSigningKey = "0xA9B2618B04CED76F";

    # System
    kimchi.enable = true;
    xdg.enable = true;
    packages.enable = true;
    packages.desktop.enable = true;
    scripts.enable = true;
  };
}
