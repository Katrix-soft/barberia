# Construir la app de Flutter Web
FROM ghcr.io/cirruslabs/flutter:3.35.7 AS build
WORKDIR /app

# Copiar configuración primero para usar el caché de Docker
COPY pubspec.* ./
RUN flutter pub get

# Copiar el resto y construir
COPY . .
RUN flutter build web --release --web-renderer canvaskit

# Servir con Nginx Alpine
FROM nginx:alpine
# Copiar configuración nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Copiar los archivos compilados del stage 1
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
