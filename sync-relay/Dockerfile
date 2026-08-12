FROM dart:3.11.5 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock analysis_options.yaml ./
RUN dart pub get --enforce-lockfile
COPY bin bin
COPY lib lib
RUN dart compile exe bin/server.dart -o /app/holoui-sync-relay

FROM debian:bookworm-slim
RUN useradd --create-home --uid 10001 holoui \
    && mkdir -p /data/holoui-sync \
    && chown -R holoui:holoui /data
COPY --from=build /app/holoui-sync-relay /usr/local/bin/holoui-sync-relay
USER 10001:10001
ENV PORT=8080 HOLOUI_RELAY_BIND=0.0.0.0 HOLOUI_RELAY_DATA=/data/holoui-sync
VOLUME ["/data/holoui-sync"]
EXPOSE 8080
STOPSIGNAL SIGTERM
ENTRYPOINT ["/bin/sh", "-c", "umask 077 && exec /usr/local/bin/holoui-sync-relay"]
