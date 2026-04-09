FROM dart:stable

WORKDIR /app

# Instalar dependencias necesarias para sqflite_common_ffi y healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    ca-certificates \
    wget && \
    rm -rf /var/lib/apt/lists/*

# Copiar configuración de dependencias
COPY pubspec.yaml .
RUN dart pub get

# Copiar todo el código fuente
COPY . .

# Directorio de la bd
RUN mkdir -p /data

EXPOSE 8090

# Se usa JIT (dart run) porque el VPS no tiene RAM suficiente para "dart compile exe" (Error 255)
CMD ["dart", "run", "bin/server.dart"]
