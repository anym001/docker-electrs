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

ENV APP_UID=99 \
    APP_GID=100 \
    APP_USER=electrs \
    APP_HOME=/home/electrs \
    DATA_DIR=/data

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates gosu bash \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN if ! getent group "${APP_GID}" >/dev/null; then \
        groupadd -g "${APP_GID}" "${APP_USER}"; \
    else \
        existing_group=$(getent group "${APP_GID}" | cut -d: -f1); \
        echo "Using existing group: $existing_group"; \
        APP_USER_GROUP="$existing_group"; \
    fi \
    && useradd -u "${APP_UID}" -g "${APP_GID}" -m -d "${APP_HOME}" -s /usr/sbin/nologin "${APP_USER}" \
    && mkdir -p "${DATA_DIR}" \
    && chown -R "${APP_UID}:${APP_GID}" "${DATA_DIR}"

COPY --from=builder /src/target/release/electrs /usr/local/bin/electrs
RUN chmod 0755 /usr/local/bin/electrs

EXPOSE 50001

CMD ["gosu", "99:100", "electrs", "--conf", "/data/electrs.toml"]
