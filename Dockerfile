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
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Verify the release tag's SSH signature against Roman Zeyde's pinned signing
# key. electrs switched tag signing from GPG to SSH as of v0.11, so we verify
# via OpenSSH allowed-signers (ssh-keygen, from openssh-client) instead of a
# keyserver GPG fetch. The key is vendored in keys/electrs-allowed-signers
# (SHA256:GifMn7F2swVKyn6MewbQHrYCs4i/bPK7gnwxhuPz/YA) — review it on bump.
COPY keys/electrs-allowed-signers /etc/electrs-allowed-signers

RUN git clone --depth 1 --branch "${ELECTRS_VERSION}" \
    https://github.com/romanz/electrs.git .

RUN git -c gpg.format=ssh \
        -c gpg.ssh.allowedSignersFile=/etc/electrs-allowed-signers \
        verify-tag "${ELECTRS_VERSION}"

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

RUN mkdir -p ${DATA_DIR} ${APP_USER_HOME}

COPY --chmod=0755 --from=builder /src/target/release/electrs /usr/local/bin/electrs

COPY scripts/ /opt/scripts
RUN chmod -R 0755 /opt/scripts/

EXPOSE 50001 4224

WORKDIR /data

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]
CMD ["--conf", "/data/electrs.toml"]
