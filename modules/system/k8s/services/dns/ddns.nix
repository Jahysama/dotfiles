{ pkgs, inputs, lib, vars }:

with lib;

let
  cronJobResource = {
    apiVersion = "batch/v1";
    kind = "CronJob";
    metadata = {
      name = "cloudflare-ddns";
      namespace = vars.namespaces.dns;
    };
    spec = {
      schedule = "*/5 * * * *";
      concurrencyPolicy = "Forbid";
      successfulJobsHistoryLimit = 1;
      failedJobsHistoryLimit = 1;
      jobTemplate.spec.template.spec = {
        restartPolicy = "OnFailure";
        containers = [{
          name = "ddns";
          image = "badouralix/curl-jq";
          command = [ "/bin/sh" "-c" ];
          args = [ ''
            CF_TOKEN=$(cat /secrets/api-token)

            CURRENT_IP=$(curl -sf https://api.ipify.org)
            echo "Current public IP: $CURRENT_IP"

            get_zone_id() {
              ZONE_ID=$(curl -sf \
                "https://api.cloudflare.com/client/v4/zones?name=$1" \
                -H "Authorization: Bearer $CF_TOKEN" | jq -r '.result[0].id')
              if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
                echo "ERROR: Could not find Cloudflare zone for $1 (token may lack Zone.Read permission)" >&2
                return 1
              fi
              echo "$ZONE_ID"
            }

            update_record() {
              ZONE_ID="$1"
              DOMAIN="$2"
              PROXIED="$3"

              RECORD=$(curl -sf \
                "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$DOMAIN" \
                -H "Authorization: Bearer $CF_TOKEN")

              CF_IP=$(echo "$RECORD" | jq -r '.result[0].content')
              RECORD_ID=$(echo "$RECORD" | jq -r '.result[0].id')

              if [ "$CURRENT_IP" = "$CF_IP" ]; then
                echo "IP unchanged for $DOMAIN: $CURRENT_IP"
                return 0
              fi

              if [ "$RECORD_ID" = "null" ] || [ -z "$RECORD_ID" ]; then
                curl -sf -X POST \
                  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
                  -H "Authorization: Bearer $CF_TOKEN" \
                  -H "Content-Type: application/json" \
                  -d "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$CURRENT_IP\",\"ttl\":60,\"proxied\":$PROXIED}" \
                  | jq -e '.success' > /dev/null || { echo "ERROR: Failed to create A record for $DOMAIN" >&2; return 1; }
              else
                curl -sf -X PATCH \
                  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
                  -H "Authorization: Bearer $CF_TOKEN" \
                  -H "Content-Type: application/json" \
                  -d "{\"content\":\"$CURRENT_IP\",\"proxied\":$PROXIED,\"ttl\":60}" \
                  | jq -e '.success' > /dev/null || { echo "ERROR: Failed to update A record for $DOMAIN" >&2; return 1; }
              fi

              echo "Updated $DOMAIN to $CURRENT_IP"
            }

            ZONE_ID_EGOR=$(get_zone_id "${vars.domain}") || exit 1
            update_record "$ZONE_ID_EGOR" "vpn.${vars.domain}" false
            update_record "$ZONE_ID_EGOR" "signal.${vars.domain}" false
            update_record "$ZONE_ID_EGOR" "telegram.${vars.domain}" false

            ZONE_ID_MLSHIP=$(get_zone_id "mlship.dev") || exit 1
            update_record "$ZONE_ID_MLSHIP" "mlship.dev" true
          ''];
          volumeMounts = [{
            name = "cf-token";
            mountPath = "/secrets";
            readOnly = true;
          }];
        }];
        volumes = [{
          name = "cf-token";
          secret.secretName = "cloudflare-api-token";
        }];
      };
    };
  };
in {
  cloudflare-ddns = lib.mkRawManifest {
    name = "cloudflare-ddns";
    namespace = vars.namespaces.dns;
    resources = [ cronJobResource ];
  };
}
