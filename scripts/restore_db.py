#!/usr/bin/env python3
"""Restaura SOLO el volcado del esquema public de Linkding en un destino nuevo.

Sin --confirmar CONFIRMAR_RESTAURACION no se escribe nada; con --dry-run se
simula. El destino debe estar vacio: nunca se sobrescriben datos existentes.
El .env no viaja en el respaldo: lo restaura el operador aparte, cifrado.
"""
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from respaldo_contrato import (auditar, ejecutar, ejecutar_check, escribir_informe,
                               opciones_restore)

SOFTWARE = "hefesto-biblioteca"
VERSION = "1.47.0"
DATABASE = "postgresql"
RAIZ = Path(__file__).resolve().parents[1]
os.chdir(RAIZ)


def dc(*args, **kw):
    return subprocess.run(["docker", "compose", *args], check=True, **kw)


def main():
    modo, origen = opciones_restore(sys.argv[1:])
    backup = Path(origen).resolve()
    ejecutar_check(str(backup), SOFTWARE, VERSION, DATABASE)
    dump = backup / "public.dump"
    if modo == "dry-run":
        print("Simulacion: el respaldo es integro y no se escribio nada.")
        print("Para restaurar de verdad: --confirmar CONFIRMAR_RESTAURACION")
        return 0
    for service in ["app"]:
        if dc("ps", "--status", "running", "-q", service, capture_output=True, text=True).stdout.strip():
            raise SystemExit("Detener Linkding antes de restaurar en destino nuevo")
    count = dc("run", "--rm", "--no-deps", "-T", "--entrypoint", "psql", "dbtools", "-Atc",
               "SELECT count(*) FROM pg_tables WHERE schemaname='public'",
               capture_output=True, text=True).stdout.strip()
    if count != "0":
        raise SystemExit("public no esta vacio; no se sobrescribiran datos")
    with dump.open("rb") as stream:
        toc = dc("run", "--rm", "--no-deps", "-T", "--entrypoint", "pg_restore", "dbtools",
                 "--list", stdin=stream, stdout=subprocess.PIPE).stdout.decode()
    # public already exists in Supabase. Do not drop it or restore its SCHEMA creation entry.
    lines = [line for line in toc.splitlines()
             if not re.match(r"^\d+;\s+\d+\s+\d+\s+SCHEMA\s+-\s+public(?:\s|$)", line)]
    with tempfile.TemporaryDirectory(prefix="hefesto-restore-") as d:
        path = Path(d) / "restore.list"
        path.write_text("\n".join(lines) + "\n")
        os.chmod(d, 0o755)
        os.chmod(path, 0o644)
        with dump.open("rb") as stream:
            dc("run", "--rm", "--no-deps", "-T", "-v", d + ":/restore:ro", "--entrypoint",
               "pg_restore", "dbtools", "--exit-on-error", "--no-owner", "--no-acl",
               "--use-list=/restore/restore.list", "--dbname=postgres", stdin=stream)
    escribir_informe(backup, software=SOFTWARE, version=VERSION, database=DATABASE,
                     modo="confirmado", resultado="restaurado", destino=str(RAIZ))
    auditar(RAIZ, operacion="restore", kit=SOFTWARE, origen=str(backup),
            destino=str(RAIZ), resultado="restaurado")
    print("Base restaurada. Restaure archivos antes de iniciar Linkding.")
    return 0


if __name__ == "__main__":
    raise SystemExit(ejecutar(main))
