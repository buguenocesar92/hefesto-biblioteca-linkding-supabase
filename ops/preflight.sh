#!/bin/sh
set -eu
[ "$SUPABASE_DEDICATED_CONFIRMED" = true ] || { echo 'Confirme proyecto Supabase exclusivo'; exit 1; }
[ "$SUPABASE_DATA_API_DISABLED" = true ] || { echo 'Desactive Data API y confirme variable'; exit 1; }
# Normaliza el sslmode a minúsculas y rechaza valores no soportados para
# que un typo no caiga en una rama permisiva por accidente.
pgmode=$(printf '%s' "${PGSSLMODE:-verify-full}" | tr '[:upper:]' '[:lower:]')
case "$pgmode" in
  verify-ca|verify-full)
    [ -s "${PGSSLROOTCERT:-}" ] || { echo 'Falta certificado CA'; exit 1; }
    ;;
  disable|allow|prefer|require)
    # Modos sin verificación de CA. Admitirlos exige una confirmación
    # explícita: un DB_SSLMODE permisivo accidental no debe pasar en
    # silencio. Con allow/prefer/require un MITM puede hacer downgrade
    # activo del handshake TLS.
    if [ "${HEFESTO_INSECURE_DB_OK:-false}" != true ]; then
      echo "ADVERTENCIA: sslmode=$pgmode desactiva la verificación de CA" >&2
      echo "Para confirmar, exportar HEFESTO_INSECURE_DB_OK=true" >&2
      exit 1
    fi
    echo "ADVERTENCIA: sslmode=$pgmode con verificación TLS relajada" >&2
    ;;
  *)
    echo "PGSSLMODE no soportado: $pgmode (esperado verify-ca|verify-full|disable|allow|prefer|require)" >&2
    exit 1
    ;;
esac
export PGCONNECT_TIMEOUT=15
psql --no-psqlrc -v ON_ERROR_STOP=1 -f /opt/hefesto/preflight.sql
