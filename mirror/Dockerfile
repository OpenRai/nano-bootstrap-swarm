FROM alpine:3.19 AS builder

RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    boost-dev \
    boost-system \
    boost-python3 \
    openssl-dev \
    python3-dev \
    py3-pip \
    libstdc++

WORKDIR /build

RUN git clone --branch RC_2_0 --depth 1 https://github.com/arvidn/libtorrent.git

WORKDIR /build/libtorrent
RUN mkdir build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -Dpython-bindings=ON \
    -Dpython-install-system=ON \
    -Dthin-lto=OFF \
    -DBUILD_SHARED_LIBS=ON && \
    make -j$(nproc) && \
    make install

RUN python3 -c "import libtorrent; print(libtorrent.version)"


FROM alpine:3.19

RUN apk add --no-cache \
    python3 \
    py3-pip \
    boost-system \
    boost-python3 \
    libstdc++ \
    openssl \
    zstd \
    && rm -rf /var/cache/apk/*

COPY --from=builder /usr/local/lib/libtorrent* /usr/local/lib/
COPY --from=builder /usr/lib/python3*/site-packages/libtorrent* /usr/lib/python3/site-packages/
COPY --from=builder /usr/local/lib/python3*/site-packages/libtorrent* /usr/lib/python3/site-packages/

RUN ldconfig /usr/local/lib 2>/dev/null || true && \
    python3 -c "import libtorrent; print('libtorrent', libtorrent.version)"

COPY requirements-mirror.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --break-system-packages -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

WORKDIR /app
COPY shared/ /app/shared/
COPY mirror/ /app/mirror/

ENV PYTHONPATH=/app
ENV DATA_DIR=/data
ENV AUTHORITY_PUBKEY=""
ENV POLL_INTERVAL=600
ENV LOG_LEVEL=INFO

VOLUME /data

EXPOSE 6881/tcp 6881/udp

HEALTHCHECK --interval=60s --timeout=10s --retries=3 \
    CMD python3 -c "import libtorrent; s=libtorrent.session({'enable_dht':False}); print('ok')" || exit 1

CMD ["python3", "-m", "mirror.watcher"]