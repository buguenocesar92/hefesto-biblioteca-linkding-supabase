"""Django overrides supported by upstream custom settings mount."""
import os
SESSION_COOKIE_SECURE = os.environ.get('HEFESTO_SECURE_COOKIES', 'true') == 'true'
CSRF_COOKIE_SECURE = SESSION_COOKIE_SECURE
# The sole ingress proxy must overwrite X-Forwarded-Proto and preserve Host.
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SESSION_COOKIE_HTTPONLY = True
