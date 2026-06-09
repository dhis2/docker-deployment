FROM alpine:3.23

ARG MKCERT_VERSION=v1.4.4
ARG TARGETARCH=amd64

RUN apk add --no-cache --virtual .fetch ca-certificates curl \
    && curl -fsSL -o /usr/local/bin/mkcert "https://dl.filippo.io/mkcert/${MKCERT_VERSION}?for=linux/${TARGETARCH}" \
    && chmod +x /usr/local/bin/mkcert \
    && apk del .fetch
