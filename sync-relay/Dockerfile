FROM dart:3.11.5 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock analysis_options.yaml ./
RUN dart pub get --enforce-lockfile
COPY bin bin
COPY lib lib
RUN dart compile exe bin/server.dart -o /app/gloss-sync-relay

FROM debian:bookworm-slim
RUN useradd --create-home --uid 10001 gloss \
    && mkdir -p /data/gloss-sync \
    && chown -R gloss:gloss /data
COPY --from=build /app/gloss-sync-relay /usr/local/bin/gloss-sync-relay
USER 10001:10001
ENV PORT=8080 GLOSS_RELAY_BIND=0.0.0.0 GLOSS_RELAY_DATA=/data/gloss-sync
VOLUME ["/data/gloss-sync"]
EXPOSE 8080
STOPSIGNAL SIGTERM
ENTRYPOINT ["/bin/sh", "-c", "umask 077 && exec /usr/local/bin/gloss-sync-relay"]
