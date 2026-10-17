# Aceptación pendiente
- docker compose config --quiet con .env real y CA legible.
- Preflight rechaza base ajena/no confirmada; migraciones con rol limitado.
- Crear administrador, dos usuarios normales y comprobar separación y opciones de compartir.
- HTTPS, CSRF/login y cookies seguras detrás de proxy; /health funciona con Host correcto.
- Importar demo HTML, buscar, etiquetar, editar nota, archivar/exportar y comprobar caracteres.
- Bloqueo de destinos internos para recuperación de metadatos; no usar URLs privadas reales en prueba.
- Reiniciar: datos, secretkey.txt y cola persisten.
- Backup/restauración en destino nuevo conserva usuarios y marcadores.
- Plan de actualización: respaldo, ensayo en copia aislada, misma versión para restauración, ventana de mantenimiento.

Validación local del kit: sintaxis Python/shell, YAML, generación de secretos sin sobrescritura, estructura HTML y ZIP. No se ejecutó aplicación real ni base Supabase.
