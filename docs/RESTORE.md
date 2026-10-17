# Restaurar y traspasar
1. Preparar destino aislado con Linkding1.47.0, nuevo Supabase y nuevo VOLUME_PREFIX. Mantener origen intacto y app destino detenida.
2. Preparar SQL/CA. Recuperar .env, compose.yaml y custom.py (va en ops/custom.py) del respaldo de confianza. Cambiar DB_HOST/USER/PASSWORD/APP_HOST para destino. Verificar hashes de configuración contra manifest antes de usarla.
3. `docker compose run --rm preflight`.
4. `python3 scripts/restore_db.py /ruta/respaldo` exige public vacío y verifica checksum; no borra datos.
5. `python3 scripts/restore_files.py /ruta/respaldo` exige volumen vacío, valida hash/rutas, restaura todo y asigna UID33. Conserva secretkey.txt y cola local.
6. Arrancar aislado con override bootstrap y revisar cuentas, marcadores, etiquetas, notas y archivos. La cola restaurada puede volver a contactar URLs pendientes: para ensayo sin tareas agregar temporalmente LD_DISABLE_BACKGROUND_TASKS=True y LD_SUPERVISOR_MANAGED=False al entorno app; verificar que no hay workers antes de operar.
7. Para corte final detener escritores/importaciones, respaldo final, restaurar en destino limpio, cambiar DNS/proxy, reactivar workers y validar. Mantener hostname cuando sea posible para extensiones/API. Revocar y regenerar tokens si cambia el responsable del servicio.

Fallo parcial: no reintentar sobre datos mezclados; usar destino nuevo. No ejecutar dos versiones sobre la misma base. Backup PostgreSQL no incluye esquema administrado Supabase, y exportación HTML no sustituye full backup. Probar restauración periódicamente.

Traspaso a otro gestor: exportar marcadores HTML por usuario e importar en destino. Usuarios, permisos, notas especiales, archivos y etiquetas pueden necesitar mapeo; verificar muestra antes de dar por migrado. Odoo: enlazar biblioteca desde portal o desarrollar adaptador backend API, no incluido. No se instala módulo Odoo ni sincronización automática.
