FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    ca-certificates \
    wget && \
    rm -rf /var/lib/apt/lists/*

COPY bin/server_linux_amd64 /app/bin/server
RUN chmod +x /app/bin/server

RUN mkdir -p /data

EXPOSE 8090

CMD ["/app/bin/server"]
