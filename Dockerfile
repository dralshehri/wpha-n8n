ARG BASE_VERSION
ARG NODE_VERSION=22

# Build stage - build n8n with customizations
FROM n8nio/base:${NODE_VERSION} AS builder

# Install build dependencies
RUN apk add --no-cache python3 make g++ bash

# Install pnpm
RUN npm install -g pnpm@10.16.1

# Clone n8n source at specific version
ARG BASE_VERSION
RUN git clone --depth 1 --branch n8n@${BASE_VERSION} https://github.com/n8n-io/n8n.git /n8n

WORKDIR /n8n

# Copy overrides to apply customizations
COPY overrides /tmp/overrides
COPY scripts/apply-overrides.sh /tmp/

# Apply overrides to source code
RUN bash /tmp/apply-overrides.sh && rm -rf /tmp/overrides /tmp/apply-overrides.sh

# Install dependencies and build n8n
RUN pnpm install --frozen-lockfile && \
    pnpm build && \
    node scripts/build-n8n.mjs

# Final stage - extend official n8n image with our compiled version
FROM n8nio/n8n:${BASE_VERSION}

# Switch to root to replace n8n
USER root

# Remove original n8n and replace with our custom build
RUN rm -rf /usr/local/lib/node_modules/n8n
COPY --from=builder /n8n/compiled /usr/local/lib/node_modules/n8n

# Rebuild native modules and recreate symlink
RUN cd /usr/local/lib/node_modules/n8n && \
    npm rebuild sqlite3 && \
    ln -sf /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    cd /usr/local/lib/node_modules/n8n/node_modules/pdfjs-dist && \
    npm install @napi-rs/canvas

# Switch back to node user
USER node

# Use the original entrypoint
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]