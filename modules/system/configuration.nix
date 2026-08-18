{ config, pkgs, inputs, username, ... }:

{

  imports = [
    ./steam
    ./packages
    ./stylix
    ./unifi
    ./sops
    ./desktop
    ./impermanence
    ./disko
    ./k3s
    ./k8s
    ./wireguard
  ];

  # Remove unnecessary preinstalled packages
  environment.defaultPackages = [ ];

  # Nix settings, auto cleanup and enable flakes
  nix = {
    settings.auto-optimise-store = true;
    settings.allowed-users = [ "${username}" ];
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-old";
    };
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
      trusted-users = root ${username}
    '';
  };

  boot = {
    kernelModules = [ "btusb" "btintel" "v4l2loopback" ];
    extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    kernelParams = [ "usbcore.autosuspend=-1" "btusb.enable_autosuspend=0" ];
    extraModprobeConfig = ''
      # Options for Bluetooth modules
      options btusb reset=1
      options btintel debug=1
      options btusb enable_autosuspend=0

      # Options for Wi-Fi to prevent interference with Bluetooth
      options iwlwifi bt_coex_active=0 swcrypto=1

      # Virtual camera for sharing webcam between multiple apps
      options v4l2loopback devices=1 video_nr=10 card_label="VCam" exclusive_caps=0
    '';
    tmp.cleanOnBoot = true;
    loader = {
      efi.canTouchEfiVariables = true;
      timeout = 10;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
        configurationLimit = 10; # Keep 10 generations in boot menu
      };
    };
  };

  # swapDevices = [{
  #   device = "/swapfile";
  #   size = 32000; # Size in MB (16GB in this example)
  # }];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50; # Use up to 50% of RAM for compressed swap
  };

  # Set up locales (timezone and keyboard layout)
  time.timeZone = "Asia/Almaty";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "ja_JP.UTF-8/UTF-8" ];
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # Enable fish shell
  programs.fish.enable = true;

  # Set up user and enable sudo
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "input" "wheel" "gamemode" "video" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQRS6OzC9Ip5lUhIyFvG03KgyupxJE55gmY3Dis0u18 cluster"
    ];
    shell = pkgs.fish;
  };

  services.openssh = {
    hostKeys = [
      { path = "/persist/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
      { path = "/persist/etc/ssh/ssh_host_rsa_key"; type = "rsa"; bits = 4096; }
    ];
  };

  programs.ssh = {
    extraConfig = ''
      Host *
        User ${username}
        IdentityFile /home/${username}/.ssh/ssh_host_ed25519_key
        IdentitiesOnly yes
        StrictHostKeyChecking no
    '';
  };

  users.users.root = {
    hashedPasswordFile = config.sops.secrets.user_password.path;
  };

  # Set up networking and secure it
  networking = {
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 443 80 27036 27037 ];
      allowedUDPPorts = [ 443 80 44857 27031 27036 8001 ];
      allowPing = false;
    };
  };

  # Set environment variables
  environment.sessionVariables = {
    NIXOS_CONFIG = "$HOME/.dotfiles";
    # NIXOS_CONFIG_DIR = "$HOME/.dotfiles";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_RUNTIME_DIR = "/run/user/1000";
    PASSWORD_STORE_DIR = "$HOME/.local/share/password-store";
    ZK_NOTEBOOK_DIR = "$HOME/stuff/notes/";
    EDITOR = "nvim";
    DIRENV_LOG_FORMAT = "";
    ANTHROPIC_API_KEY_LOAD = config.sops.secrets.antropic_key.path;
    GITHUB_TOKEN_PATH = config.sops.secrets.github_token.path;
    GITHUB_EMAIL_PATH = config.sops.secrets.git_email.path;
    CLOUDFLARE_EMAIL_PATH = config.sops.secrets.cloudflare_email.path;
    SOPS_AGE_KEY_FILE = "/persist/etc/sops-nix/keys.txt";
  };

  # Security 
  security = {
    pam.services.swaylock = { };
    sudo = {
      enable = true;
      extraRules = [{
        users = [ "${username}" ];
        commands = [{
          command = "ALL";
          options = [ "SETENV" "NOPASSWD" ];
        }];
      }];
    };
    # Extra security
    protectKernelImage = true;
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez5-experimental;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = with pkgs; [ linux-firmware ];

  system.stateVersion = "24.05";
}
