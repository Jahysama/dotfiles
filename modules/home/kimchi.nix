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
    models_path = os.path.join(home, ".config", "kimchi", "harness", "models.json")

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

    claude_models = [
      {"id": "claude-sonnet-4-6", "name": "Claude Sonnet 4.6", "api": "anthropic-messages",
       "baseUrl": "https://api.anthropic.com", "reasoning": True, "input": ["text", "image"],
       "contextWindow": 1000000, "maxTokens": 128000,
       "cost": {"input": 3, "output": 15, "cacheRead": 0.3, "cacheWrite": 3.75},
       "provider": "anthropic",
       "compat": {"forceAdaptiveThinking": True, "supportsStrictTools": True}},
      {"id": "claude-opus-4-8", "name": "Claude Opus 4.8", "api": "anthropic-messages",
       "baseUrl": "https://api.anthropic.com", "reasoning": True, "input": ["text", "image"],
       "contextWindow": 1000000, "maxTokens": 128000,
       "cost": {"input": 5, "output": 25, "cacheRead": 0.5, "cacheWrite": 6.25},
       "provider": "anthropic",
       "compat": {"forceAdaptiveThinking": True, "supportsTemperature": False, "supportsStrictTools": True}},
      {"id": "claude-haiku-4-5", "name": "Claude Haiku 4.5", "api": "anthropic-messages",
       "baseUrl": "https://api.anthropic.com", "reasoning": True, "input": ["text", "image"],
       "contextWindow": 200000, "maxTokens": 64000,
       "cost": {"input": 1, "output": 5, "cacheRead": 0.1, "cacheWrite": 1.25},
       "provider": "anthropic",
       "compat": {"supportsStrictTools": True}},
      {"id": "claude-fable-5", "name": "Claude Fable 5", "api": "anthropic-messages",
       "baseUrl": "https://api.anthropic.com", "reasoning": True, "input": ["text", "image"],
       "contextWindow": 1000000, "maxTokens": 128000,
       "cost": {"input": 10, "output": 50, "cacheRead": 1, "cacheWrite": 12.5},
       "provider": "anthropic",
       "compat": {"forceAdaptiveThinking": True, "supportsStrictTools": True}},
    ]

    try:
        with open(models_path) as f:
            models_cfg = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        models_cfg = {}

    models_cfg.setdefault("providers", {})["anthropic"] = {
        "api": "anthropic-messages",
        "baseUrl": "https://api.anthropic.com",
        "models": claude_models,
    }

    with open(models_path, "w") as f:
        json.dump(models_cfg, f, indent="\t")

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
