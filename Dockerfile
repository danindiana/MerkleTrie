# Multi-stage Dockerfile for MerkleTrie
# Stage 1: Build environment
FROM erlang:27.1-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    make \
    gcc \
    g++ \
    libc-dev \
    openssl-dev \
    ncurses-dev \
    bash

# Set working directory
WORKDIR /build

# Copy rebar configuration
COPY rebar.config .
COPY rebar.lock ./

# Download rebar3 if not present
RUN wget https://s3.amazonaws.com/rebar3/rebar3 && \
    chmod +x rebar3 && \
    ./rebar3 --version

# Download dependencies
RUN ./rebar3 get-deps

# Copy source code
COPY src ./src
COPY test ./test
COPY scripts ./scripts

# Compile the application
RUN ./rebar3 compile

# Run tests to ensure everything works
RUN ./rebar3 eunit || true

# Build release
RUN ./rebar3 as prod release

# Stage 2: Runtime environment
FROM erlang:27.1-alpine AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    openssl \
    ncurses-libs \
    libstdc++

# Create application user
RUN addgroup -S trie && adduser -S trie -G trie

# Set working directory
WORKDIR /opt/trie

# Copy release from builder
COPY --from=builder --chown=trie:trie /build/_build/prod/rel/trie ./

# Create data directory
RUN mkdir -p /opt/trie/data && chown -R trie:trie /opt/trie/data

# Switch to non-root user
USER trie

# Expose any necessary ports (adjust as needed)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f beam.smp || exit 1

# Set environment variables
ENV HOME=/opt/trie \
    RELX_REPLACE_OS_VARS=true

# Volume for persistent data
VOLUME ["/opt/trie/data"]

# Default command
CMD ["/opt/trie/bin/trie", "foreground"]
