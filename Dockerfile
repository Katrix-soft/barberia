# Build stage
FROM ghcr.io/cirruslabs/flutter:3.35.7 AS build
WORKDIR /app

# Habilitar web y precache
RUN flutter config --enable-web
RUN flutter precache --web

# Copiar dependencias primero
COPY pubspec.* ./
RUN flutter pub get

# Copiar el resto del código
COPY . .

# Build web - Usamos canvaskit para mejor fidelidad visual
RUN flutter build web --release --no-tree-shake-icons --web-renderer canvaskit

# Runtime stage
FROM nginx:alpine

# Configuración de Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Archivos compilados
COPY --from=build /app/build/web /usr/share/nginx/html

# Plantilla y script de entrada
COPY web/env.template.js /usr/share/nginx/html/env.template.js
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Exponer puerto default
EXPOSE 80

# Iniciar vía el entrypoint para inyectar variables de entorno
ENTRYPOINT ["/entrypoint.sh"]
