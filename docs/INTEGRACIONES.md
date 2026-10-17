# Integraciones posibles
Extensiones oficiales/bookmarklet: conectar URL de la instancia y credencial del usuario según documentación. Tokens pertenecen al usuario; no usar token administrador en navegador compartido ni exportaciones.

API REST: integrar n8n/Laravel desde backend con usuario dedicado, token guardado en gestor de secretos y HTTPS. Antes de automatizar escrituras, consultar documentación de versión y probar paginación, duplicados y permisos en una cuenta de prueba. Este kit no configura conexiones externas.

Importación inicial: examples/demo-bookmarks.html contiene solo tres referencias públicas. Importar desde ajustes de Linkding con un usuario de prueba, comprobar etiquetas y exportar de vuelta. La obtención de títulos/vistas previas puede generar solicitudes web externas; ejecutar importaciones grandes en lotes y observar cola.

No habilitar LD_ALLOWED_INTERNAL_HOSTS=* ni desactivar validación global de URL. No introducir proxies HTTP que eludan protección de destinos internos. Si requiere guardar enlaces intranet, definir acceso específico según red real y evaluar por separado recuperación de metadatos.

Usuarios pueden activar funciones de compartición; revisar antes de guardar enlaces confidenciales. El hecho de tener login no vuelve privadas todas las páginas compartidas que alguien habilite.
