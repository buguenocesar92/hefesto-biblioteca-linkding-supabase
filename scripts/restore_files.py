#!/usr/bin/env python3
"""Restaura los archivos (adjuntos y notas) de Linkding en un volumen vacio.

Sin --confirmar CONFIRMAR_RESTAURACION no se escribe nada; con --dry-run se
simula. El volumen destino debe estar vacio: nunca se sobrescriben archivos.
"""
import os
import subprocess
import sys
import tarfile
from pathlib import Path, PurePosixPath

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
    p = Path(origen).resolve()
    ejecutar_check(str(p), SOFTWARE, VERSION, DATABASE)
    a = p / "files.tar.gz"
    with tarfile.open(a) as tf:
        seen = set()
        for member in tf:
            name = PurePosixPath(member.name)
            if (name.is_absolute() or ".." in name.parts
                    or not (member.isfile() or member.isdir())
                    or str(name) in seen):
                raise SystemExit("Ruta/tipo no admitido")
            seen.add(str(name))
    if modo == "dry-run":
        print("Simulacion: el respaldo es integro y no se escribio nada.")
        print("Para restaurar de verdad: --confirmar CONFIRMAR_RESTAURACION")
        return 0
    if dc("ps", "--status", "running", "-q", "app", capture_output=True, text=True).stdout.strip():
        raise SystemExit("Detener app")
    found = dc("run", "--rm", "--no-deps", "-T", "--entrypoint", "find", "filetools", "/files",
               "-mindepth", "1", "-maxdepth", "1", capture_output=True, text=True).stdout.strip()
    if found:
        raise SystemExit("Volumen no vacío; no se sobrescribe")
    with a.open("rb") as f:
        dc("run", "--rm", "--no-deps", "-T", "--user", "0", "--entrypoint", "tar", "filetools",
           "-xzf", "-", "-C", "/files", stdin=f)
    dc("run", "--rm", "--no-deps", "permissions")
    escribir_informe(p, software=SOFTWARE, version=VERSION, database=DATABASE,
                     modo="confirmado", resultado="restaurado", destino=str(RAIZ))
    auditar(RAIZ, operacion="restore", kit=SOFTWARE, origen=str(p),
            destino=str(RAIZ), resultado="restaurado")
    print("Archivos restaurados y propietario ajustado.")
    return 0


if __name__ == "__main__":
    raise SystemExit(ejecutar(main))
