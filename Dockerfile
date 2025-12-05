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
    APP_UID=99 \
    APP_GID=100 \
    DATA_DIR=/data \
    DATA_PERM=2770 \
    UMASK=002

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gosu \
        bash \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN if ! getent group "${APP_GID}" >/dev/null; then \
        groupadd -g "${APP_GID}" "${APP_USER}"; \
    else \
        GROUP_NAME=$(getent group "${APP_GID}" | cut -d: -f1); \
        echo "GID ${APP_GID} already exists, using group ${GROUP_NAME}"; \
        APP_USER_GROUP="${GROUP_NAME}"; \
    fi \
    && useradd -u "${APP_UID}" -g "${APP_GID}" -m -d "${APP_USER_HOME}" -s /usr/sbin/nologin "${APP_USER}" \
    && mkdir -p "${DATA_DIR}" \
    && chown "${APP_UID}:${APP_GID}" "${DATA_DIR}"

COPY --from=builder /src/target/release/electrs /usr/local/bin/electrs
RUN chmod 0755 /usr/local/bin/electrs \
    && chown root:root /usr/local/bin/electrs

COPY scripts/ /opt/scripts
RUN chmod -R 0755 /opt/scripts/

EXPOSE 50001

ENTRYPOINT ["bash", "/opt/scripts/entrypoint.sh"]
CMD ["electrs"]
