# ----------------------------------------------------
# Build stage
# ----------------------------------------------------
FROM rust:slim AS builder

ARG ELECTRS_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        clang \
        libclang-dev \
        llvm-dev \
        cmake \
        build-essential \
        pkg-config \
        libssl-dev \
        librocksdb-dev \
        git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone https://github.com/romanz/electrs.git . \
    && git fetch --tags --prune \
    && git checkout "${ELECTRS_VERSION}"

RUN cargo build --release

# ----------------------------------------------------
# Runtime stage
# ----------------------------------------------------
FROM debian:stable-slim

ARG ELECTRS_VERSION

ENV APP_USER=electrs \
    APP_USER_HOME=/home/electrs \
    DATA_DIR=/data

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        bash \
        gosu \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${DATA_DIR} ${APP_HOME}

COPY --from=builder /src/target/release/electrs /usr/local/bin/electrs
RUN chmod 0755 /usr/local/bin/electrs

COPY scripts/ /opt/scripts
RUN chmod -R 0755 /opt/scripts/

EXPOSE 50001

WORKDIR /data

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]
CMD ["--conf", "/data/electrs.toml"]
