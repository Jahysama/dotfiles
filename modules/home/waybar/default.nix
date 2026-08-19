{ pkgs, lib, config, ... }:
with lib;
let cfg = config.modules.waybar;
in {
  options.modules.waybar = { enable = mkEnableOption "waybar"; };
  config = mkIf cfg.enable {
    programs.waybar = {
      enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 40;
          modules-left =
            [ "hyprland/workspaces" "hyprland/language" "custom/spotify" ];
          modules-center = [ "clock" ];
          modules-right = [ "custom/vpn" "network" "backlight" "wireplumber" "battery" ];
          "hyprland/language" = {
            format-en = "US";
            format-ru = "RU";
            min-length = 5;
            tooltip = false;
          };
          "hyprland/workspaces" = {
            "on-click" = "activate";
            "format" = "{icon}";
            "format-icons" = {
              "default" = "";
              "1" = "1";
              "2" = "2";
              "3" = "3";
              "4" = "4";
              "5" = "5";
              "6" = "6";
              "7" = "7";
              "8" = "8";
              "9" = "9";
            };
            "persistent_workspaces" = {
              "1" = [ ];
              "2" = [ ];
              "3" = [ ];
              "4" = [ ];
              "5" = [ ];
            };
          };
          "clock" = {
            "tooltip-format" = "{calendar}";
            "format" = "{:%I:%M %p | %a, %d %b %Y}";
          };
          "network" = {
            "format-wifi" = "{icon}  {essid}";
            "format-icons" = [ "󰤯" "󰤟" "󰤢" "󰤥" "󰤨" ];
            "format-ethernet" = "󰀂 {ifname}";
            "format-disconnected" = "󰖪 Disconnected";
            "tooltip-format-wifi" = ''
              {icon} {essid}
              ⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}'';
            "tooltip-format-ethernet" = ''
              󰀂  {ifname}
              ⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}'';
            "tooltip-format-disconnected" = "Disconnected";
            "interval" = 5;
            "nospacing" = 1;
          };
          "backlight" = {
            "format" = "{icon}";
            "format-icons" = [ "󰃚" "󰃛" "󰃜" "󰃝" "󰃞" "󰃟" "󰃠" ];
            "tooltip-format" = "Brightness: {percent}%";
            "on-scroll-up" = "brightnessctl set +5%";
            "on-scroll-down" = "brightnessctl set 5%-";
            "min-length" = 1;
          };
          "wireplumber" = {
            "format" = "{icon}  {volume}%";
            "format-bluetooth" = "󰂰 {volume}%";
            "format-muted" = "󰝟";
            "format-icons" = {
              "headphone" = "󰋋";
              "hands-free" = "󰂑";
              "headset" = "󰋎";
              "phone" = "󰏲";
              "portable" = "󰦢";
              "car" = "󰄋";
              "default" = [ "󰕿" "󰖀" "󰕾" ];
            };

            "scroll-step" = 1;
            "on-click" = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            "on-scroll-up" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+";
            "on-scroll-down" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-";
            "tooltip" = true;
            "tooltip-format" = "{icon} {volume}%";
          };
          "battery" = {
            "format" = "{capacity}% {icon}";
            "format-icons" = {
              "charging" = [ "󰢜" "󰂆" "󰂇" "󰂈" "󰢝" "󰂉" "󰢞" "󰂊" "󰂋" "󰂅" ];
              "default" = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
            };
            "format-full" = "Charged ";
            "interval" = 5;
            "states" = {
              "warning" = 20;
              "critical" = 10;
            };
            "tooltip" = false;
          };
          "custom/vpn" = {
            "format" = "{}";
            "return-type" = "json";
            "exec" = ''
              if systemctl is-active --quiet wg-quick-japan; then
                echo '{"text": "󰖂 JP", "class": "connected"}'
              else
                echo '{"text": "󰖪 JP", "class": "disconnected"}'
              fi
            '';
            "on-click" = ''
              if systemctl is-active --quiet wg-quick-japan; then
                sudo systemctl stop wg-quick-japan
              else
                sudo systemctl start wg-quick-japan
              fi
            '';
            "interval" = 5;
            "tooltip" = false;
          };
          "custom/spotify" = {
            "format" = "{icon} {text}";
            "format-icons" = { "default" = "󰓇"; };
            "escape" = true;
            "return-type" = "json";
            "max-length" = 40;
            "interval" = 1;
            "signal" = 5;
            "exec" = ''
              PLAYBACK=$(spotify_player get key playback)
              if [ $? -eq 0 ]; then
                ARTIST=$(echo "$PLAYBACK" | jq -r '.item.artists[0].name')
                TITLE=$(echo "$PLAYBACK" | jq -r '.item.name')
                ALBUM=$(echo "$PLAYBACK" | jq -r '.item.album.name')
                IS_PLAYING=$(echo "$PLAYBACK" | jq -r '.is_playing')
                echo "{\"text\": \"$ARTIST - $TITLE\", \"tooltip\": \"$TITLE by $ARTIST from $ALBUM\", \"alt\": \"$IS_PLAYING\", \"class\": \"$IS_PLAYING\"}"
              else
                echo "{\"text\": \"No music playing\", \"tooltip\": \"Spotify not running\", \"alt\": \"stopped\", \"class\": \"stopped\"}"
              fi
            '';
          };
        };
      };

      style = builtins.readFile ./style.css;
    };
  };
}
