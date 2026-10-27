#!/usr/bin/env bats
# Ciclo backup -> restore de hefesto-biblioteca-linkding-supabase con datos
# sinteticos. Nunca toca el .env real ni Docker real.

load 'ayudante.bash'

setup() {
  preparar_kit
  preparar_datos
  unset AGE_RECIPIENT || true
  unset AGE_RECIPIENTE || true
}

@test "backup.py exige el .env antes de hacer nada" {
  rm -f "$KIT/.env"
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -ne 0 ]
}

@test "backup.py genera el manifiesto con las cinco claves del contrato" {
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  [ -f "$RESPALDO/manifest.json" ]
  python3 - "$RESPALDO/manifest.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
for clave in ("software", "version", "database", "sha256", "status"):
    assert clave in m, "falta la clave " + clave
assert m["status"] == "completed", m["status"]
assert m["sha256"], "sha256 vacio"
PY
}

@test "el .env NO se copia en claro al respaldo" {
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  [ ! -f "$RESPALDO/.env" ]
  [ -f "$RESPALDO/env.vars" ]
  run grep -R -F "valor-ficticio-no-real" "$RESPALDO"
  [ "$status" -ne 0 ]
}

@test "con receptor age el .env viaja cifrado y se descifra byte a byte" {
  if ! generar_receptor_age; then skip "age-keygen no disponible en este entorno"; fi
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  [ -f "$RESPALDO/env.age" ]
  run grep -R -F "valor-ficticio-no-real" "$RESPALDO"
  [ "$status" -ne 0 ]
  age -d -i "$BATS_TEST_TMPDIR/age/clave.txt" "$RESPALDO/env.age" > "$BATS_TEST_TMPDIR/env.plano"
  cmp "$BATS_TEST_TMPDIR/env.plano" "$KIT/.env"
}

@test "check_backup acepta el respaldo integro" {
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  run python3 "$KIT/scripts/check_backup.py" "$RESPALDO"
  [ "$status" -eq 0 ]
}

@test "check_backup rechaza un artefacto alterado" {
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  printf 'alterado\n' >> "$RESPALDO/files.tar.gz"
  run python3 "$KIT/scripts/check_backup.py" "$RESPALDO"
  [ "$status" -eq 2 ]
}

@test "check_backup rechaza un .env en claro dentro del respaldo" {
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  cp "$KIT/.env" "$RESPALDO/.env"
  run python3 "$KIT/scripts/check_backup.py" "$RESPALDO"
  [ "$status" -eq 4 ]
}

@test "check_backup rechaza un respaldo no completado" {
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  python3 -c "import json,sys; p=sys.argv[1]; m=json.load(open(p)); m['status']='failed'; json.dump(m, open(p,'w'))" "$RESPALDO/manifest.json"
  run python3 "$KIT/scripts/check_backup.py" "$RESPALDO"
  [ "$status" -eq 2 ]
}

@test "restore_db.py sin --confirmar no restaura" {
  export STUB_RUNNING=0
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  run python3 "$KIT/scripts/restore_db.py" "$RESPALDO"
  [ "$status" -eq 3 ]
  [ ! -f "$RESPALDO/restore-report.json" ]
}

@test "restore_db.py en dry-run no escribe nada" {
  export STUB_RUNNING=0
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  run python3 "$KIT/scripts/restore_db.py" "$RESPALDO" --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$RESPALDO/restore-report.json" ]
  [ ! -d "$KIT/logs" ]
}

@test "restore_db.py con --confirmar restaura y deja informe y auditoria" {
  export STUB_RUNNING=0
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  run python3 "$KIT/scripts/restore_db.py" "$RESPALDO" --confirmar CONFIRMAR_RESTAURACION
  [ "$status" -eq 0 ]
  [ -f "$RESPALDO/restore-report.json" ]
  [ -f "$KIT/logs/restore.log" ]
  run grep -F "restore" "$KIT/logs/restore.log"
  [ "$status" -eq 0 ]
}

@test "restore_db.py se niega a sobrescribir un public que no esta vacio" {
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  export STUB_PSQL_OUT=5
  run python3 "$KIT/scripts/restore_db.py" "$RESPALDO" --confirmar CONFIRMAR_RESTAURACION
  [ "$status" -ne 0 ]
  [ ! -f "$RESPALDO/restore-report.json" ]
}

@test "restore_files.py sin --confirmar no restaura" {
  export STUB_RUNNING=0
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  run python3 "$KIT/scripts/restore_files.py" "$RESPALDO"
  [ "$status" -eq 3 ]
  [ ! -f "$RESPALDO/restore-report.json" ]
}

@test "restore_files.py en dry-run no escribe nada" {
  export STUB_RUNNING=0
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  run python3 "$KIT/scripts/restore_files.py" "$RESPALDO" --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$RESPALDO/restore-report.json" ]
}

@test "restore_files.py con --confirmar restaura y deja informe y auditoria" {
  export STUB_RUNNING=0
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  run python3 "$KIT/scripts/restore_files.py" "$RESPALDO" --confirmar CONFIRMAR_RESTAURACION
  [ "$status" -eq 0 ]
  [ -f "$RESPALDO/restore-report.json" ]
  [ -f "$KIT/logs/restore.log" ]
}

@test "restore_files.py se niega a sobrescribir un volumen con contenido" {
  run python3 "$KIT/scripts/backup.py"
  [ "$status" -eq 0 ]
  RESPALDO="$(respaldo_reciente)"
  export STUB_FIND_OUTPUT="dato-previo.txt"
  run python3 "$KIT/scripts/restore_files.py" "$RESPALDO" --confirmar CONFIRMAR_RESTAURACION
  [ "$status" -ne 0 ]
  [ ! -f "$RESPALDO/restore-report.json" ]
}

@test "el compose declara security_opt en el servicio app" {
  run bash -c "awk '/^  app:/{f=1;next} /^  [a-z]/{f=0} f&&/no-new-privileges/{print \"ok\"}' '$KIT/compose.yaml' | grep -q ok"
  [ "$status" -eq 0 ]
}

@test "el compose fija postgres por digest en los cuatro servicios" {
  run grep -c "postgres:17-alpine@sha256:" "$KIT/compose.yaml"
  [ "$output" -eq 4 ]
}
