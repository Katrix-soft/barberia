# ── Stage 1: compilar AOT ──────────────────────────────────────────
FROM dart:stable AS builder

WORKDIR /app

COPY pubspec.yaml .
RUN dart pub get

COPY . .

# Compilar binario nativo AOT (mucho menos RAM que dart run)
RUN dart compile exe bin/server.dart -o bin/server

# ── Stage 2: imagen final mínima ───────────────────────────────────
FROM debian:bookworm-slim

WORKDIR /app

# Solo lo necesario para correr el binario y el healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    ca-certificates \
    wget && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /runtime/ /
COPY --from=builder /app/bin/server /app/bin/server

RUN mkdir -p /data

EXPOSE 8090

CMD ["/app/bin/server"]
