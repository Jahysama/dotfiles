{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.modules.kimchi;

  syncScript = pkgs.writeScript "kimchi-claude-sync.py" ''
    #!${pkgs.python3}/bin/python3
    import json, os, sys

    home = os.path.expanduser("~")
    claude_creds = os.path.join(home, ".claude", ".credentials.json")
    auth_path = os.path.join(home, ".config", "kimchi", "harness", "auth.json")

    try:
        with open(claude_creds) as f:
            creds = json.load(f)
    except FileNotFoundError:
        print("~/.claude/.credentials.json not found, skipping", file=sys.stderr)
        sys.exit(0)

    oauth = creds.get("claudeAiOauth", {})
    access = oauth.get("accessToken")
    refresh = oauth.get("refreshToken", "")
    expires = oauth.get("expiresAt", 9999999999999)

    if not access:
        print("No accessToken in Claude credentials", file=sys.stderr)
        sys.exit(1)

    os.makedirs(os.path.dirname(auth_path), exist_ok=True)

    try:
        with open(auth_path) as f:
            auth = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        auth = {}

    auth["anthropic"] = {"type": "oauth", "access": access, "refresh": refresh, "expires": expires}

    with open(auth_path, "w") as f:
        json.dump(auth, f, indent=2)
    os.chmod(auth_path, 0o600)

    print("kimchi: synced Claude subscription credentials")
  '';
in
{
  options.modules.kimchi = {
    enable = mkEnableOption "kimchi Claude credential sync";
  };

  config = mkIf cfg.enable {
    home.activation.kimchiClaudeSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${syncScript}
    '';

    systemd.user.services.kimchi-claude-sync = {
      Unit.Description = "Sync Claude Code OAuth credentials into Kimchi";
      Service = {
        Type = "oneshot";
        ExecStart = "${syncScript}";
      };
    };

    systemd.user.timers.kimchi-claude-sync = {
      Unit.Description = "Periodically re-sync Claude credentials to Kimchi";
      Timer = {
        OnBootSec = "1min";
        OnUnitActiveSec = "30min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
