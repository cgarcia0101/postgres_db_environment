FROM alpine:3.19

RUN apk add --no-cache openssh-client

ARG SSH_KEY_FILE
COPY ${SSH_KEY_FILE} /root/ssh_key

COPY redis-dev/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
