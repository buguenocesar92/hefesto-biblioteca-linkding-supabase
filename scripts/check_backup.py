#!/usr/bin/env python3
"""Verificacion de integridad de un respaldo de hefesto-biblioteca.

Codigos de salida:
  0  respaldo integro
  1  uso incorrecto
  2  manifiesto o checksum invalido
  4  material sensible en claro dentro del respaldo
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from respaldo_contrato import ejecutar, ejecutar_check

SOFTWARE = "hefesto-biblioteca"
VERSION = "1.47.0"
DATABASE = "postgresql"
# El kit no tiene volumenes con claves: el unico material sensible es el .env,
# que el contrato detecta de forma generica.
PROHIBIDOS = []


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Uso: python3 scripts/check_backup.py /ruta/respaldo")
    ejecutar_check(sys.argv[1], SOFTWARE, VERSION, DATABASE, prohibidos=PROHIBIDOS)
    print("Manifiesto, checksums y ausencia de secretos en claro verificados.")
    print("No demuestra la recuperacion de Supabase ni del .env: hace falta la clave age.")
    return 0


if __name__ == "__main__":
    raise SystemExit(ejecutar(main))
