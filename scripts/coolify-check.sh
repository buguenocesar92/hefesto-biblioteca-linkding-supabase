#!/usr/bin/env bash
# Verifica que los compose del repositorio cumplan el contrato de Coolify
# para la app `biblioteca` (rama coolify). Falla con "servicio: motivo" si
# encuentra algo prohibido o si el render no expone los valores parametrizados
# exigidos por el contrato (DB_NAME y DB_SSLMODE).
#
# No lee .env reales ni secretos. Genera un env-file temporal con valores
# ficticios no secretos para poder renderizar.
#
# Uso: bash scripts/coolify-check.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Composiciones a inspeccionar. El bootstrap es solo para dev local y puede
# mantener sus `ports:` de loopback.
COMPOSES=("compose.yaml")

# Tipo de BD del kit (define qué variables de BD hay que validar en el render).
BD_TIPO="supabase-pg"

errores=0
falla() { echo "FALLA: $*" >&2; errores=$((errores+1)); }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
envfile="$tmpdir/env.tmp"

# 1) Extraer todas las variables ${VAR} (con o sin :-/:?/:=) que el compose
# espera. Lo aplicamos a cada compose inspeccionado.
vars_collect=""
for compose in "${COMPOSES[@]}"; do
  [[ -f "$compose" ]] || continue
  extra=$(grep -oE '\$\{[A-Z_][A-Z0-9_]*(:[-=?+][^}]*)?\}' "$compose" \
    | sed -E 's/^\$\{([A-Z_][A-Z0-9_]*).*/\1/' \
    | sort -u) || true
  vars_collect="$vars_collect"$'\n'"$extra"
done
# Variables explícitas conocidas del contrato (fuerza su presencia).
vars_collect="$vars_collect"$'\n'"DB_SSLMODE"$'\n'"DB_NAME"$'\n'"DB_HOST"$'\n'"DB_USER"$'\n'"DB_PASSWORD"$'\n'"APP_HOST"$'\n'"VOLUME_PREFIX"$'\n'"SUPABASE_DEDICATED_CONFIRMED"$'\n'"SUPABASE_DATA_API_DISABLED"

vars=$(printf '%s\n' "$vars_collect" | tr ' ' '\n' | sort -u | sed '/^$/d')

# 2) Generar env.tmp con valores ficticios no secretos.
: > "$envfile"
for v in $vars; do
  case "$v" in
    *HOST*|*URL*) printf '%s=https://ejemplo.invalid\n' "$v" >> "$envfile" ;;
    *)            printf '%s=x1234567890abcdef\n' "$v" >> "$envfile" ;;
  esac
done

# Para supabase-pg, forzar DB_SSLMODE=disable y DB_NAME=mvp_prueba para
# validar que el compose expone esos valores en el render.
if [[ "$BD_TIPO" == "supabase-pg" ]]; then
  printf 'DB_SSLMODE=disable\n' >> "$envfile"
  printf 'DB_NAME=mvp_prueba\n' >> "$envfile"
fi

for compose in "${COMPOSES[@]}"; do
  if [[ ! -f "$compose" ]]; then
    falla "falta $compose"
    continue
  fi

  echo "Renderizando $compose con variables ficticias..."
  rendered="$tmpdir/rendered.json"
  if ! docker compose --project-directory "$REPO_ROOT" -f "$compose" --env-file "$envfile" config --format json > "$rendered" 2>"$tmpdir/stderr"; then
    cat "$tmpdir/stderr" >&2
    falla "$compose: no se pudo renderizar con docker compose config"
    continue
  fi

  # 3) Contrato: no `name:` literal en la raíz ni en bloques de volumen. Si
  # el valor contiene una variable (`${...}`) no es fijo, Coolify lo respeta.
  # Lo validamos en la fuente porque el render resuelve las variables y no
  # podríamos distinguir un literal de una variable.
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    val=$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*name:[[:space:]]*//; s/[[:space:]]*$//')
    case "$val" in
      *'${'*) ;;
      *) falla "$compose: 'name: $val' literal está prohibido por el contrato (Coolify asigna el nombre)" ;;
    esac
  done < <(grep -E '^[[:space:]]*name:' "$compose" 2>/dev/null || true)

  # 5) Servicios sin `profiles` (los que Coolify va a levantar): validar
  # prohibiciones del contrato.
  if jq -e '.services != null' "$rendered" >/dev/null; then
    while IFS= read -r svc; do
      [[ -z "$svc" ]] && continue
      # Recoger los profiles declarados en el render; si contiene "tools"
      # pertenece a un perfil opcional y se omite.
      svc_profiles=$(jq -r --arg k "$svc" '.services[$k].profiles // [] | join(" ")' "$rendered")
      if [[ " $svc_profiles " == *" tools "* ]]; then
        continue
      fi

      # ports: prohibido
      if jq -e --arg k "$svc" '.services[$k].ports != null' "$rendered" >/dev/null; then
        falla "$svc: declara 'ports' (Coolify enruta el dominio; no exponer puertos)"
      fi
      # container_name: prohibido
      if jq -e --arg k "$svc" '.services[$k].container_name != null' "$rendered" >/dev/null; then
        falla "$svc: declara 'container_name' (Coolify pone el nombre)"
      fi
      # privileged / cap_add / devices: prohibidos
      for prop in privileged cap_add devices; do
        if jq -e --arg k "$svc" --arg p "$prop" '.services[$k][$p] != null' "$rendered" >/dev/null; then
          falla "$svc: declara '$prop' (prohibido por el contrato)"
        fi
      done
      # network_mode: host prohibido
      nm=$(jq -r --arg k "$svc" '.services[$k].network_mode // ""' "$rendered")
      if [[ "$nm" == "host" ]]; then
        falla "$svc: 'network_mode: host' prohibido"
      fi
      # pid/ipc: host prohibido
      for prop in pid ipc; do
        v=$(jq -r --arg k "$svc" --arg p "$prop" '.services[$k][$p] // ""' "$rendered")
        if [[ "$v" == "host" ]]; then
          falla "$svc: '$prop: host' prohibido"
        fi
      done
      # security_opt: unconfined prohibido
      if jq -e --arg k "$svc" '.services[$k].security_opt // [] | map(select(. == "unconfined" or test("unconfined"))) | length > 0' "$rendered" >/dev/null; then
        falla "$svc: 'security_opt: unconfined' prohibido"
      fi
      # Binds: deben estar bajo el repo y nunca docker.sock
      while IFS= read -r src; do
        [[ -z "$src" ]] && continue
        case "$src" in
          *docker.sock*) falla "$svc: bind a docker.sock prohibido" ;;
          "$REPO_ROOT"/*) ;;
          *) falla "$svc: bind fuera del repo: $src" ;;
        esac
      done < <(jq -r --arg k "$svc" '.services[$k].volumes // [] | .[] | select(.type == "bind") | .source' "$rendered")
    done < <(jq -r '.services | keys[]' "$rendered")
  fi

  # 6) supabase-pg: el render debe exponer el nombre de BD parametrizado
  # (mvp_prueba) y sslmode disable.
  if [[ "$BD_TIPO" == "supabase-pg" ]]; then
    if ! jq -e '.. | objects | to_entries[] | select(.value == "mvp_prueba")' "$rendered" >/dev/null; then
      falla "$compose: el render no expone 'mvp_prueba' (ni PGDATABASE ni LD_DB_DATABASE usan DB_NAME)"
    fi
    if ! jq -e '.. | strings | select(. == "disable")' "$rendered" >/dev/null; then
      falla "$compose: el render no expone 'disable' (ni PGSSLMODE ni LD_DB_OPTIONS usan DB_SSLMODE)"
    fi
  fi
done

if [[ "$errores" -gt 0 ]]; then
  echo "Errores: $errores" >&2
  exit 1
fi

echo "OK: contrato de Coolify cumplido en ${COMPOSES[*]}"
exit 0
