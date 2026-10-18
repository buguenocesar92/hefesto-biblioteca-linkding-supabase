#!/bin/sh
set -eu
[ "$SUPABASE_DEDICATED_CONFIRMED" = true ] || { echo 'Confirme proyecto Supabase exclusivo'; exit 1; }
[ "$SUPABASE_DATA_API_DISABLED" = true ] || { echo 'Desactive Data API y confirme variable'; exit 1; }
# El certificado CA solo es obligatorio cuando sslmode exige verificación.
# Con sslmode=disable (por ejemplo, enlace directo dentro de la red Docker)
# no se necesita CA: el DSN no lleva sslrootcert y el bind ./certs puede
# quedar vacío.
case "${PGSSLMODE:-verify-full}" in
  disable|allow|prefer|require) ;;
  *) [ -s "${PGSSLROOTCERT:-}" ] || { echo 'Falta certificado CA'; exit 1; } ;;
esac
export PGCONNECT_TIMEOUT=15
psql --no-psqlrc -v ON_ERROR_STOP=1 -f /opt/hefesto/preflight.sql
