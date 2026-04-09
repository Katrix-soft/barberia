FROM dart:stable

WORKDIR /app

# Instalar dependencias necesarias para sqflite_common_ffi
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

# Directorio de la bd (por si acaso el volumen se monta aquí)
RUN mkdir -p /data

EXPOSE 8090

# Usar JIT en lugar de AOT (exe) para evitar crash de compilador
CMD ["dart", "run", "bin/server.dart"]
