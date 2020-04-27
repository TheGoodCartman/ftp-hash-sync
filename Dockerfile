FROM alpine:latest
RUN apk --no-cache add bash ftp
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
