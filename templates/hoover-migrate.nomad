{% from '_lib.hcl' import migration_reschedule -%}

job "hoover-migrate" {
  datacenters = ["dc1"]
  type = "batch"

  ${ migration_reschedule() }

  group "search" {
    task "migrate" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-search"
        args = ["./manage.py", "migrate"]
        volumes = [
          ${hoover_search_repo}
          "${liquid_volumes}/hoover-ui/build:/opt/hoover/ui/build",
        ]
        labels {
          liquid_task = "hoover-search"
        }
      }
      template {
        data = <<EOF
          {{- if keyExists "liquid_debug" }}
            DEBUG = {{key "liquid_debug"}}
          {{- end }}
          {{- with secret "liquid/hoover/search.django" }}
            SECRET_KEY = {{.Data.secret_key}}
          {{- end }}
          {{- range service "hoover-pg" }}
            HOOVER_DB = postgresql://hoover:hoover@{{.Address}}:{{.Port}}/hoover
          {{- end }}
          {{- range service "hoover-es" }}
            HOOVER_ES_URL = http://{{.Address}}:{{.Port}}
          {{- end }}
          HOOVER_HOSTNAME = hoover.{{key "liquid_domain"}}
          {{- with secret "liquid/hoover/search.oauth2" }}
            LIQUID_AUTH_PUBLIC_URL = http://{{key "liquid_domain"}}
            {{- range service "core" }}
              LIQUID_AUTH_INTERNAL_URL = http://{{.Address}}:{{.Port}}
            {{- end }}
            LIQUID_AUTH_CLIENT_ID = {{.Data.client_id}}
            LIQUID_AUTH_CLIENT_SECRET = {{.Data.client_secret}}
          {{- end }}
        EOF
        destination = "local/hoover.env"
        env = true
      }
    }
  }
}
