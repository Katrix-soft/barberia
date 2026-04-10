# Construir la app de Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Habilitar web
RUN flutter config --enable-web
RUN flutter precache --web

# Copiar configuración
COPY pubspec.* ./
RUN flutter pub get

# Copiar código
COPY . .

# Build web
RUN flutter build web --release --no-tree-shake-icons --web-renderer canvaskit

# Servir con Nginx
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
