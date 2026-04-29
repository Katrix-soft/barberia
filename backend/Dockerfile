FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app
COPY backend/ .
RUN flutter pub get --suppress-analytics
RUN dart build bin/server.dart -o bin/server_linux_amd64

FROM debian:bookworm-slim
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsqlite3-0 ca-certificates wget && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/bin/server_linux_amd64 /app/bin/server
RUN chmod +x /app/bin/server
RUN mkdir -p /data

EXPOSE 8090
CMD ["/app/bin/server"]
