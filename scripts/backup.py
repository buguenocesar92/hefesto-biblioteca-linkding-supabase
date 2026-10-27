#!/usr/bin/env python3
"""Respaldo de hefesto-biblioteca-linkding-supabase (Linkding + Supabase).

Reglas de material sensible:
- El .env NUNCA se copia en claro: solo env.vars (nombres de las variables) y,
  si hay receptor age, el .env cifrado (env.age). Contiene DB_PASSWORD y
  APP_HOST.
- Sin receptor age el respaldo sale SIN el .env y el manifiesto lo declara.
  No existe modo degradado a texto plano.
- manifest.json lleva siempre software, version, database, sha256 y status.

Ver docs/CONTRATO-RESPALDO.md.
"""
import datetime
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from respaldo_contrato import (ejecutar, escribir_manifiesto, exportar_env,
                               marcar_fallido, receptor_age)

SOFTWARE = "hefesto-biblioteca"
VERSION = "1.47.0"
DATABASE = "postgresql"
RAIZ = Path(__file__).resolve().parents[1]
os.chdir(RAIZ)
os.umask(0o077)

# Artefactos del respaldo. El .env NO esta: va cifrado o fuera.
COPIAS = ["custom.py", "compose.yaml"]
VOLUMENES = ["public.dump", "files.tar.gz"]
VARS_RECIPIENTE = ("AGE_RECIPIENT", "SOPS_AGE_RECIPIENT")


def dc(*args, **kw):
    return subprocess.run(["docker", "compose", *args], check=True, **kw)


def receptor_del_env() -> str:
    """Clave publica age declarada en el .env del kit (si el operador la puso).

    No se imprime ni se escribe en ningun sitio: el respaldo usa unicamente la
    parte publica.
    """
    origen = RAIZ / ".env"
    if not origen.is_file():
        return ""
    for linea in origen.read_text(encoding="utf-8", errors="replace").splitlines():
        texto = linea.strip()
        if not texto or texto.startswith("#") or "=" not in texto:
            continue
        clave, valor = texto.split("=", 1)
        clave = clave.strip()
        valor = valor.strip().strip("'\"")
        if clave in VARS_RECIPIENTE and valor:
            return valor
    return ""


def main():
    if not (RAIZ / ".env").is_file():
        raise SystemExit("Falta .env: el kit no se puede respaldar sin el archivo real.")

    if not receptor_age():
        candidato = receptor_del_env()
        if candidato:
            os.environ["AGE_RECIPIENT"] = candidato

    carpeta = RAIZ / "backups" / datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y%m%dT%H%M%S%fZ")
    carpeta.mkdir(parents=True, mode=0o700)
    running = bool(dc("ps", "--status", "running", "-q", "app",
                      capture_output=True, text=True).stdout.strip())
    try:
        dc("stop", "app")
        with (carpeta / "public.dump").open("wb") as salida:
            dc("run", "--rm", "--no-deps", "-T", "--entrypoint", "pg_dump", "dbtools",
               "--format=custom", "--schema=public", "--no-owner", "--no-acl", stdout=salida)
        with (carpeta / "files.tar.gz").open("wb") as salida:
            dc("run", "--rm", "--no-deps", "-T", "--entrypoint", "tar", "filetools",
               "-czf", "-", "-C", "/files", ".", stdout=salida)
        for nombre in COPIAS:
            origen = RAIZ / nombre
            if origen.is_file():
                shutil.copy2(origen, carpeta / nombre)
        meta = exportar_env(RAIZ, carpeta)
        artefactos = [n for n in VOLUMENES + COPIAS if (carpeta / n).is_file()]
        artefactos.append("env.vars")
        if (carpeta / "env.age").is_file():
            artefactos.append("env.age")
        escribir_manifiesto(carpeta, SOFTWARE, VERSION, DATABASE, artefactos, extra=meta)
    except Exception:
        marcar_fallido(carpeta, SOFTWARE, VERSION, DATABASE)
        raise
    finally:
        if running:
            dc("start", "app")
    print("Respaldo completo:", carpeta)
    print("El .env no viaja en claro: solo nombres de variables, o cifrado con age.")
    return 0


if __name__ == "__main__":
    raise SystemExit(ejecutar(main))
