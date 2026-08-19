{ pkgs, lib, config, ... }:
with lib;
let cfg = config.modules.packages.core;
in {
  options.modules.packages.core = { enable = mkEnableOption "core packages"; };
  config = mkIf cfg.enable {
    home.shellAliases = {
      # zoxide replacement for cd
      cd = "z";

      # ripgrep replacement for grep
      grep = "rg --smart-case";
    };

    programs.zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
    };

    home.packages = with pkgs; [
      # Development
      git
      gh
      lua
      terraform
      terragrunt
      opentofu

      # Python
      python3
      ruff
      python3Packages.flake8
      python3Packages.black

      # Go
      go
      golangci-lint
      gopls
      go-tools

      # Nix
      statix
      nil
      nixfmt

      # Lua
      stylua

      # JavaScript/TypeScript/Web
      prettier
      eslint
      jq

      # Rust
      rustc
      cargo
      rustfmt
      rust-analyzer
      clippy
      gcc

      # C/C++ & PlatformIO
      clang-tools
      platformio

      # Cloud & Container Tools
      google-cloud-sdk
      awscli
      kubectl

      # System Utils
      htop
      yazi
      fzf
      ripgrep
      bat
      eza
      unzip
      tealdeer
      age
      tree
      vhs

      # AI Coding Agent
      kimchi
    ];

    home.activation.installPonytail = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      marker="$HOME/.config/kimchi/.ponytail-installed"
      if [ ! -f "$marker" ]; then
        echo "Installing ponytail for kimchi..."
        if $DRY_RUN_CMD ${pkgs.kimchi}/bin/kimchi install git:github.com/DietrichGebert/ponytail 2>/dev/null; then
          $DRY_RUN_CMD touch "$marker"
        else
          echo "Ponytail install skipped (run 'kimchi setup' first, then 'kimchi install git:github.com/DietrichGebert/ponytail')"
        fi
      fi
    '';
  };
}

