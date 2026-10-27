# ayudante: kit de pruebas aislado para hefesto-biblioteca-linkding-supabase.
#
# Nunca toca el .env real ni Docker real: el kit se copia a un directorio
# temporal con un .env sintetico y el stub de tests/stubs/docker responde por
# Docker.
RAIZ="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export RAIZ
export HEFESTO_KIT_TEST=1
export PATH="$RAIZ/tests/stubs:$PATH"

preparar_kit() {
  KIT="$BATS_TEST_TMPDIR/kit"
  rm -rf "$KIT"
  mkdir -p "$KIT"
  cp -R "$RAIZ/scripts" "$KIT/scripts"
  rm -rf "$KIT/scripts/__pycache__"
  for extra in compose.yaml compose.bootstrap.yaml .env.example; do
    if [ -f "$RAIZ/$extra" ]; then cp "$RAIZ/$extra" "$KIT/$extra"; fi
  done
  if [ -d "$RAIZ/ops" ]; then cp -R "$RAIZ/ops" "$KIT/ops"; fi
  if [ -d "$RAIZ/certs" ]; then cp -R "$RAIZ/certs" "$KIT/certs"; fi
  mkdir -p "$KIT/backups"
  printf 'DB_HOST=db.ejemplo.supabase.co\nDB_USER=linkding_app\nDB_PASSWORD=valor-ficticio-no-real\nAPP_HOST=biblioteca.ejemplo.cl\n' > "$KIT/.env"
  chmod 600 "$KIT/.env"
  export KIT
}

preparar_datos() {
  export STUB_DUMP_FILE="$BATS_TEST_TMPDIR/dump.sql"
  printf -- '-- dump sintetico\nCREATE TABLE demo(id int);\n' > "$STUB_DUMP_FILE"
  export STUB_TAR_DIR="$BATS_TEST_TMPDIR/tar"
  mkdir -p "$STUB_TAR_DIR/data"
  printf 'archivo sintetico\n' > "$STUB_TAR_DIR/data/demo.txt"
  export STUB_RUNNING=1
  export STUB_FIND_OUTPUT=""
  export STUB_PSQL_OUT=0
  export STUB_STATE_FILE="$BATS_TEST_TMPDIR/servicios-detenidos"
  : > "$STUB_STATE_FILE"
}

respaldo_reciente() {
  ls -d "$KIT"/backups/*/ 2>/dev/null | head -1
}

generar_receptor_age() {
  # Genera un par de claves age efimero SOLO en el directorio temporal de la
  # prueba. Nunca se versiona ni se usa fuera de la suite.
  if ! command -v age-keygen >/dev/null 2>&1; then
    return 1
  fi
  local dir="$BATS_TEST_TMPDIR/age"
  mkdir -p "$dir"
  chmod 700 "$dir"
  if ! age-keygen -o "$dir/clave.txt" >/dev/null 2>&1; then
    return 1
  fi
  AGE_RECIPIENT="$(sed -n 's/^# public key: //p' "$dir/clave.txt")"
  export AGE_RECIPIENT
  [ -n "$AGE_RECIPIENT" ]
}
