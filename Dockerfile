FROM golang:1.23 as signal-receiver
#COPY ./src .
COPY ./ .
RUN go build -o /go/bin/alertmanager-signal-receiver ./cmd/main.go
RUN strip /go/bin/alertmanager-signal-receiver

FROM ubuntu:jammy

ARG PREFIX=/app
ARG PUID=1000
ARG PGID=1000
ARG TIMEZONE=UTC

RUN apt-get update && apt-get install --no-install-recommends -y openjdk-21-jre-headless curl
RUN curl -sL -o /etc/apt/trusted.gpg.d/morph027-signal-cli.asc https://packaging.gitlab.io/signal-cli/gpg.key
RUN echo "deb https://packaging.gitlab.io/signal-cli signalcli main" | tee /etc/apt/sources.list.d/morph027-signal-cli.list
RUN apt-get update && apt-get install signal-cli-jre
RUN groupadd --gid $PGID app && \
useradd --uid $PUID --gid $PGID --comment '' --home-dir /dev/shm --no-create-home --shell /bin/bash --no-log-init app && \
mkdir -p $PREFIX/data && \
chown -R $PUID:$PGID $PREFIX

COPY --from=signal-receiver /go/bin/alertmanager-signal-receiver /usr/bin/
USER app
ENTRYPOINT ["alertmanager-signal-receiver"]
HEALTHCHECK --interval=60s --timeout=3s CMD ["wget", "-q", "-O", "-", "http://localhost:9709/healthz"]
EXPOSE 9709/tcp
VOLUME /app/data
