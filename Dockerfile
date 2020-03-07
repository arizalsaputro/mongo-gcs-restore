FROM mongo:latest

RUN apt-get update && apt-get install -y \
  bash \
  curl

RUN echo "deb http://packages.cloud.google.com/apt cloud-sdk-xenial main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
  apt-get update && \
  apt-get install -y google-cloud-sdk

ADD ./restore.sh /mongodb-gcs-restore/restore.sh
WORKDIR /mongodb-gcs-restore

RUN chmod +x /mongodb-gcs-restore/restore.sh

ENTRYPOINT ["/mongodb-gcs-restore/restore.sh"]