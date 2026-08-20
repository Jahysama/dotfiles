{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.modules.kimchi;

  setupScript = pkgs.writeScript "kimchi-setup.py" ''
    #!${pkgs.python3}/bin/python3
    import json, os

    models_path = os.path.join(os.path.expanduser("~"), ".config", "kimchi", "harness", "models.json")
    os.makedirs(os.path.dirname(models_path), exist_ok=True)

    try:
        with open(models_path) as f:
            cfg = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        cfg = {}

    cfg.setdefault("providers", {})["anthropic"] = {
        "api": "anthropic-messages",
        "baseUrl": "https://api.anthropic.com",
        "name": "Anthropic (Claude Pro/Max)",
        "auth": {"oauth": {"isSubscription": True, "name": "Anthropic (Claude Pro/Max)"}},
        "models": [
            {"id": "claude-sonnet-4-6", "name": "Claude Sonnet 4.6", "api": "anthropic-messages", "baseUrl": "https://api.anthropic.com", "reasoning": True, "input": ["text", "image"], "contextWindow": 1000000, "maxTokens": 128000, "cost": {"input": 3, "output": 15, "cacheRead": 0.3, "cacheWrite": 3.75}, "provider": "anthropic", "compat": {"forceAdaptiveThinking": True, "supportsStrictTools": True}},
            {"id": "claude-opus-4-8", "name": "Claude Opus 4.8", "api": "anthropic-messages", "baseUrl": "https://api.anthropic.com", "reasoning": True, "input": ["text", "image"], "contextWindow": 1000000, "maxTokens": 128000, "cost": {"input": 5, "output": 25, "cacheRead": 0.5, "cacheWrite": 6.25}, "provider": "anthropic", "compat": {"forceAdaptiveThinking": True, "supportsTemperature": False, "supportsStrictTools": True}},
            {"id": "claude-haiku-4-5", "name": "Claude Haiku 4.5", "api": "anthropic-messages", "baseUrl": "https://api.anthropic.com", "reasoning": True, "input": ["text", "image"], "contextWindow": 200000, "maxTokens": 64000, "cost": {"input": 1, "output": 5, "cacheRead": 0.1, "cacheWrite": 1.25}, "provider": "anthropic", "compat": {"supportsStrictTools": True}},
            {"id": "claude-fable-5", "name": "Claude Fable 5", "api": "anthropic-messages", "baseUrl": "https://api.anthropic.com", "reasoning": True, "input": ["text", "image"], "contextWindow": 1000000, "maxTokens": 128000, "cost": {"input": 10, "output": 50, "cacheRead": 1, "cacheWrite": 12.5}, "provider": "anthropic", "compat": {"forceAdaptiveThinking": True, "supportsStrictTools": True}},
        ]
    }

    with open(models_path, "w") as f:
        json.dump(cfg, f, indent="\t")
    print("kimchi: anthropic provider configured")
  '';
in
{
  options.modules.kimchi = {
    enable = mkEnableOption "kimchi provider setup";
  };

  config = mkIf cfg.enable {
    home.activation.kimchiSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${setupScript}
    '';
  };
}
