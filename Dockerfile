FROM alpine:latest

RUN apk add --update \
  bash \
  mongodb-tools \
  curl \
  python \
  py-pip \
  py-cffi \
  && pip install --upgrade pip \
  && apk add --virtual build-deps \
  gcc \
  libffi-dev \
  python-dev \
  linux-headers \
  musl-dev \
  openssl-dev \
  && pip install gsutil \
  && apk del build-deps \
  && rm -rf /var/cache/apk/*

ADD ./restore.sh /mongodb-gcs-restore/restore.sh
WORKDIR /mongodb-gcs-restore

RUN chmod +x /mongodb-gcs-restore/restore.sh

ENTRYPOINT ["/mongodb-gcs-restore/restore.sh"]