# Etapa 1: Compilar el servidor Dart
FROM dart:stable AS build

WORKDIR /app

# Copiar dependencias primero para aprovechar el caché
COPY pubspec.yaml .
RUN dart pub get

# Copiar el código fuente y compilar a binario nativo
COPY . .
RUN dart compile exe bin/server.dart -o bin/barber_backend

# Etapa 2: Imagen mínima de runtime (sin Dart SDK)
FROM debian:bookworm-slim AS runtime

WORKDIR /app

# Dependencias mínimas para el binario compilado (libsqlite3)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copiar el binario compilado
COPY --from=build /app/bin/barber_backend /app/barber_backend

# Directorio para la base de datos (se monta como volumen)
RUN mkdir -p /data

EXPOSE 8090

CMD ["/app/barber_backend"]
