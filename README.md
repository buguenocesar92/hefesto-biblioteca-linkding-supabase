# Hefesto Biblioteca · Linkding 1.47.0 + Supabase

Biblioteca de marcadores para recursos técnicos, investigación y materiales de clientes. Usa interfaz nativa Linkding: búsqueda, etiquetas, notas, lectura pendiente e importación/exportación de marcadores. Kit de infraestructura, no instancia ya desplegada.

## Arquitectura
Supabase PostgreSQL16/17 guarda usuarios y marcadores. El volumen /etc/linkding/data conserva secretkey.txt, archivos, vistas previas y la cola local Huey/SQLite. Por eso no basta con respaldar PostgreSQL. No usa Supabase Auth, Storage ni Data API. Una instancia por cliente recomendada; no es un SaaS multitenant desarrollado a medida.

Imagen básica oficial fijada1.47.0 por digest. No incluye Chromium/SingleFile ni captura HTML de páginas de la variante plus. Carga de archivos y actualización automática de favicons desactivadas inicialmente. La obtención de metadatos de páginas puede contactar sitios externos; conservar validación de URL y protección de destinos internos.

## Despliegue
Requisitos: Docker Engine, Compose v2, Python3.11+, Supabase dedicado, puerto5432 accesible, dominio y proxy HTTPS. Inicio orientativo: 1CPU/1GB para app; medir carga de importaciones/cola antes de definir capacidad.

1. `python3 scripts/configure.py`. Editar .env: DB_HOST, APP_HOST sin protocolo/puerto, y conexión. Mantener archivo0600.
2. Ejecutar sql/01-supabase-app.sql en SQL Editor como postgres, en proyecto vacío. Asignar DB_PASSWORD al rol mediante `\password linkding_app` en psql administrativo.
3. Desactivar Data API. Descargar CA oficial a certs/ca.crt. Conexión directa5432 preferida; si requiere IPv4 usar Session Pooler5432 y DB_USER=linkding_app.REFERENCIA. No usar Transaction Pooler6543. Confirmar variables SUPABASE_* después de completar tareas.
4. `docker compose -f compose.yaml -f compose.bootstrap.yaml up -d`. La app ejecuta migraciones nativas. bash -e detiene bootstrap si falla una tarea; no continúa a servir tras un fallo de migración.
5. `docker compose exec app python manage.py createsuperuser`. Usuario/correo/clave interactivos, sin contraseña predefinida.
6. Abrir http://localhost:8103. Remoto: `ssh -L 8103:127.0.0.1:8103 usuario@servidor`. Crear usuarios normales desde /admin/. Mantener perfil invitado y compartición pública sin activar. Probar marcadores con examples/demo-bookmarks.html.
7. `docker compose -f compose.yaml -f compose.bootstrap.yaml down` sin -v. Confirmar APP_HOST y ejecutar `docker compose up -d`.
8. Coolify: importar compose.yaml, ops y certs junto con variables; asignar HTTPS al servicio app:9090. No desplegar override bootstrap públicamente. Proxy debe preservar Host y sobrescribir X-Forwarded-Proto. No exponer9090 directamente. Configurar políticas de TLS en proxy.
9. Revisar salud, login, cookies seguras, usuarios normales y separación de datos. Revisar docs/ACCEPTANCE.md.

El bootstrap oficial arranca como root para preparar permisos y ejecuta procesos según configuración upstream. No forzar user arbitrario sin adaptar arranque. Datos se restauran con propietario www-data33. Conservar el volumen completo y secretkey.txt.

## Uso inicial
Crear etiquetas cliente-demo, referencia, pendiente. Añadir URL, título y notas; revisar metadatos. Usar filtros y lectura pendiente. Importar HTML desde ajustes y exportar copia periódica; HTML exportado es intercambio de marcadores, no respaldo de cuentas/archivos/cola.

## Operación
`python3 scripts/backup.py` detiene app y workers, copia public.dump + volumen completo + configuración/secretos, valida mediante hashes y reinicia si estaba activa. Usar solo modo producción base. Esperar a terminar importaciones antes de parar. Backup contiene credenciales, tokens y URLs privadas: cifrar y guardar fuera del VPS. Guía de restauración en docs/RESTORE.md.

Estado: configuración revisada estáticamente. Docker, migraciones, navegación y restauración reales pendientes de probar en infraestructura Hefesto. No se han conectado cuentas ni importado datos reales.

## Despliegue en Coolify (MVP Hefesto)

El `compose.yaml` de la rama `coolify` está pensado para importarse directo en
Coolify como build pack Docker Compose. El validador del contrato vive en
`scripts/coolify-check.sh` y se ejecuta en local antes de mergear a `main`
desde la rama `coolify` (`bash scripts/coolify-check.sh`).

Variables nuevas que debe inyectar Coolify en el servicio `app`:

- `DB_NAME`: nombre de la base dentro del proyecto Supabase dedicado. Por
  defecto `postgres` (uso original). Coolify debe usar la base exclusiva
  del kit, p. ej. `mvp_biblioteca`.
- `DB_SSLMODE`: modo SSL para libpq (vía `PGSSLMODE`). Por defecto
  `verify-full`. Con `disable` (enlace directo dentro de la red Docker o sin
  TLS) libpq no exige `sslrootcert` y la CA no es obligatoria. Coolify
  también puede sobrescribir `LD_DB_OPTIONS` completo si necesita un JSON
  específico.
- `DB_SSLROOTCERT`: ruta al CA dentro del contenedor (vía `PGSSLROOTCERT`).
  Por defecto `/certs/ca.crt` (se monta desde `./certs`).
- `LD_DB_OPTIONS`: opciones adicionales del DSN. Por defecto solo trae
  `{"connect_timeout":15}`; el `sslmode` y el `sslrootcert` los toma
  libpq de `PGSSLMODE`/`PGSSLROOTCERT`. Si Coolify necesita
  `disable` y no quiere que aparezca `sslrootcert`, lo sobrescribe completo,
  p. ej. `{"sslmode":"disable","connect_timeout":15}`.

Variables que ya existían y Coolify debe seguir inyectando: `DB_HOST`,
`DB_USER`, `DB_PASSWORD`, `APP_HOST`, `SUPABASE_DEDICATED_CONFIRMED=true`,
`SUPABASE_DATA_API_DISABLED=true`, `VOLUME_PREFIX`.

`SUPABASE_DEDICATED_CONFIRMED` y `SUPABASE_DATA_API_DISABLED` son obligatorias
y el `preflight` aborta si no están en `true`. El proyecto Supabase del MVP
Hefesto es dedicado y tiene la Data API desactivada; si Coolify no las
inyecta, el contenedor no arranca.

El certificado `certs/ca.crt` está fuera del repo. En Coolify se inyecta como
archivo de Coolify montado en `/certs/ca.crt` (read-only). Si
`DB_SSLMODE=disable`, basta con dejar el directorio `certs/` vacío
(`certs/README.md` documenta qué archivo espera cada modo).

Coolify pone el dominio y TLS; el servicio expone `9090` internamente.
Traefik entrega `Host` y `X-Forwarded-Proto: https`, que `ops/custom.py`
exige. No exponer `9090` directamente.

Crear el superusuario desde la terminal de Coolify del servicio `app`:
`python manage.py createsuperuser`.

`scripts/coolify-check.sh` corre el contrato localmente:
`bash scripts/coolify-check.sh`. Falla si el compose declara algo que Coolify
no acepta (puertos, `container_name`, `name:` raíz fijo, `privileged`, etc.)
o si la parametrización de la BD no se refleja en el render del servicio
`app` (no del preflight).
