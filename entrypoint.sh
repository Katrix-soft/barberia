#!/bin/sh

set -e



# Generar env.js desde variables de entorno de Docker

# Se usa un fallback por defecto si no están definidas

cat > /usr/share/nginx/html/env.js << EOF

window.ENV = {

  API_URL: "${API_URL:-https://api.katrix.com.ar}",

  MP_ACCESS_TOKEN: "${MP_ACCESS_TOKEN:-}",

  MP_PUBLIC_KEY: "${MP_PUBLIC_KEY:-}"

};

EOF



echo "[Entrypoint] Generated env.js with runtime variables."



# Iniciar nginx

echo "[Entrypoint] Starting Nginx..."

exec nginx -g 'daemon off;'