# ----------------------------------------------------
# Build stage
# ----------------------------------------------------
FROM rust:slim AS builder

ARG ELECTRS_VERSION

RUN apt-get update \
    && apt-get install -y \
        clang \
        libclang-dev \
        llvm-dev \
        cmake \
        build-essential \
        pkg-config \
        libssl-dev \
        git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone https://github.com/romanz/electrs.git . \
    && git checkout "${ELECTRS_VERSION}"

RUN cargo build --release

# ----------------------------------------------------
# Runtime stage
# ----------------------------------------------------
FROM debian:stable-slim

ENV APP_USER=electrs \
    APP_USER_HOME=/home/electrs \
    DATA_DIR=/data \
    DATA_PERM=2750 \
    UMASK=002 \
    PUID=99 \
    PGID=100

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gosu \
        bash \
        tini \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d ${APP_USER_HOME} -s /usr/sbin/nologin ${APP_USER} \
    && mkdir -p ${DATA_DIR}

COPY --from=builder /src/target/release/electrs /usr/local/bin/electrs
RUN chown root:root /usr/local/bin/electrs \
    && chmod 0755 /usr/local/bin/electrs

COPY scripts/ /opt/scripts/
RUN chown -R root:root /opt/scripts \
    && chmod -R 0755 /opt/scripts/

EXPOSE 50001

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]
CMD []
