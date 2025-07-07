FROM alpine:latest

ARG CURL_VERSION=8.14.1

ARG CC=clang

COPY mykey.asc /tmp

WORKDIR /tmp

RUN apk -U add gnupg build-base clang \
      openssl-dev openssl-libs-static \
      nghttp2-dev nghttp2-static \
      nghttp3-dev nghttp3-static \
      zlib-dev zlib-static

RUN wget -q https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz \
            https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz.asc

# convert mykey.asc to a .pgp file to use in verification
RUN gpg --no-default-keyring --yes -o ./curl.gpg --dearmor mykey.asc
# this has a non-zero exit code if it fails, which will halt the script
RUN gpg --no-default-keyring --keyring ./curl.gpg --verify curl-${CURL_VERSION}.tar.gz.asc

RUN tar xf curl-${CURL_VERSION}.tar.gz
WORKDIR curl-${CURL_VERSION}/

RUN LDFLAGS="-static" PKG_CONFIG="pkg-config --static" \
  ./configure --enable-optimize --disable-shared --enable-static --disable-docs --disable-manual \
              --with-openssl --without-libpsl --with-openssl-quic --with-nghttp3 --enable-httpsrr
RUN make -j$(nproc) V=1 LDFLAGS="-static -all-static"

# exit with error code 1 if the executable is dynamic, not static
RUN ldd src/curl && exit 1 || true

RUN mkdir -p /tmp/release/
RUN cp src/curl /tmp/release/curl
RUN strip /tmp/release/curl
