# Política de tratamiento de datos personales — Linkding (Hefesto Studio)

Estado: vigente desde 2026-10-20. Responsable del tratamiento: el cliente que
opera el kit. Este documento propone el marco: su aprobacion formal es del
cliente.

## 1. Qué datos trata este kit

Linkding es un **gestor de marcadores**: guarda URLs marcadas, títulos,
descripciones, notas, etiquetas y adjuntos. Conjunto, eso es un **perfil de
navegación personal**, de la categoría más intimate del grupo de kits.

El kit **no** almacena los datos de las bases de datos de negocio: los datos
viven en el proyecto Supabase dedicado del cliente. Lo que el kit hace es
proteger el camino entre Linkding y ese Supabase:

- `DB_PASSWORD` y `APP_HOST` viven en el `.env`.
- El respaldo `public.dump` contiene las URLs, títulos y notas del esquema
  `public`.

## 2. Base legal y deberes (Ley 21.719)

| Deber | Cómo se cumple en este kit |
|---|---|
| **Minimización** | Linkding guarda solo lo que el usuario marca. No hay indexación externa por defecto. |
| **Finalidad** | Gestión de marcadores del propio usuario del negocio. |
| **Seguridad** | `.env` fuera del respaldo en claro; conexión a Supabase con `verify-full` por defecto; preflight que **bloquea** si el proyecto Supabase no es exclusivo o la Data API sigue habilitada. |
| **Acceso** | El compose no publica puertos: la superficie es el borde (Coolify/Traefik) con TLS. |
| **Auditoría** | `logs/restore.log` registra cada restauración (origen, sha256 verificado, destino, resultado) sin valores de secretos. |

## 3. Minimización en la operación

1. El proyecto Supabase debe ser **exclusivo** de esta instancia: lo exige
   `ops/preflight.sh` (`SUPABASE_DEDICATED_CONFIRMED=true`).
2. La **Data API de Supabase debe estar deshabilitada**: lo exige el mismo
   preflight (`SUPABASE_DATA_API_DISABLED=true`). `.env.example` trae el
   valor `false` a propósito: el operador debe cambiarlo de forma consciente
   para que el preflight lo valide. Un ejemplo que ya dijera `true` firmaría
   una confirmación que nadie hizo.
3. El volumen `files` guarda adjuntos: puede contener documentos con datos
   personales. No se versiona nunca.

## 4. Retención

| Dato | Retención | Quién la define |
|---|---|---|
| Marcadores, títulos, notas, adjuntos | While la cuenta exista. El usuario puede borrar cada marcador; el borrado es del lado de Linkding y Supabase. | El cliente que opera el kit |
| `.env` (`DB_PASSWORD`) | Mientras viva el despliegue. Se rota revocando la clave en Supabase. | El cliente |
| Respaldos (`backups/`) | Mientras el operador los conserve. **No hay borrado automático**: borrar un respaldo es irreversible y es decisión del operador. | El cliente |
| `env.vars` / `env.age` | Viajan con el respaldo. `env.vars` solo contiene nombres de variables. | — |

La definición de los plazos concretos de supresión es **decisión del cliente**
y queda fuera de este kit: el kit no borra datos por sí mismo.

## 5. Derechos del titular

El kit no implementa un canal de atención de derechos: eso vive en la
aplicación que el cliente opera. Lo que el kit garantiza es que los datos
**existen y se pueden exportar y suprimir**: el respaldo `public.dump` es un
`pg_dump` del esquema `public`, restaurable con `scripts/restore_db.py`.

Para atender una solicitud de acceso, rectificacion o supresion:

1. El responsable exports el esquema `public` con `scripts/backup.py`.
2. Entrega el volcado al titular, **cifrado con `age`** (el `.env` va aparte).
3. La supresion se ejecuta en Supabase y en Linkding, no en el kit.

## 6. Auditoría

- `scripts/restore_db.py` y `scripts/restore_files.py` exigen
  `--confirmar CONFIRMAR_RESTAURACION` y dejan `restore-report.json` junto al
  respaldo y una linea en `logs/restore.log`.
- `scripts/check_backup.py` falla con código **4** si un `.env` aparece en
  claro dentro de un respaldo: es un control automatico, no una nota.
- El acceso al servicio es del borde (Coolify/Traefik) con TLS. Linkding CE
  tiene autenticacion propia y `LD_ENABLE_OIDC="False"`: si el cliente activa
  SSO, la `LD_ENABLE_AUTH_PROXY` y la `LD_CSRF_TRUSTED_ORIGINS` deben
  revisarse.

## 7. Integraciones (fuera de alcance de este kit)

`docs/INTEGRACIONES.md` describe integraciones con navegadores y servicios en
la nube. Cada una que saque datos del kit a un tercero necesita **su propia
base legal y su propia retencion**, y no queda cubierta por este documento.
