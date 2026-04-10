# Construir la app de Flutter Web
FROM ghcr.io/cirruslabs/flutter:3.24.5 AS build
WORKDIR /app

# Habilitar web
RUN flutter config --enable-web
RUN flutter precache --web

# Copiar configuración
COPY pubspec.* ./
RUN flutter pub get

# Copiar código
COPY . .

# Build web - Simplificado para evitar exit code 64
RUN flutter build web --release --no-tree-shake-icons

# Servir con Nginx
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
