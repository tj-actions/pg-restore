ARG POSTGRES_VERSION=${INPUT_POSTGRES_VERSION:-9.6}

FROM postgres:$POSTGRES_VERSION

LABEL maintainer="Tonye Jack <jtonye@ymail.com>"

COPY main.sh /main.sh
RUN chmod +x /main.sh

COPY cleanup.sh /cleanup.sh
RUN chmod +x /cleanup.sh

ENTRYPOINT ["/main.sh"]
