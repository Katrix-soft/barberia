# Etapa 1: Compilación
FROM dart:stable AS build

WORKDIR /app

# Copiar dependencias y descargar
COPY pubspec.yaml .
RUN dart pub get

# Copiar el resto del código y compilar a binario nativo
COPY . .
RUN dart compile exe bin/server.dart -o server

# Etapa 2: Runtime (Imagen ligera)
FROM debian:stable-slim

# Instalar librerías necesarias en tiempo de ejecución
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    ca-certificates \
    wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar el binario desde la etapa de compilación
COPY --from=build /app/server .

# Crear directorio de datos para la base de datos
RUN mkdir -p /data

EXPOSE 8090

# Ejecutar el binario directamente (más eficiente en memoria)
CMD ["./server"]
