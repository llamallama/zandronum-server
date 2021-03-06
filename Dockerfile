FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -qq --no-install-recommends \
      wget \
      gnupg \
      gettext-base \
      gosu \
      tini \
    && wget -O - http://debian.drdteam.org/drdteam.gpg | apt-key add - \
    && echo 'deb http://debian.drdteam.org/ stable multiverse' >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -qq --no-install-recommends zandronum-server \
    && cp ./usr/games/zandronum/libcrypto.so.1.0.0 ./usr/lib/x86_64-linux-gnu/ \
    && apt-get -qq autoremove wget gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV INSTALL_DIR=/usr/games/zandronum

# Install GeoIP.dat
COPY docker-files/GeoLite2-Country.mmdb "$INSTALL_DIR/GeoIP.dat"

# Environment variables used to map host UID/GID to internal
# user used to launch zandronum-server.
ENV ZANDRONUM_UID= \
    ZANDRONUM_GID=

# Config files
COPY ./servers/configs /configs
# Entrypoint
COPY ./docker-files/entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
