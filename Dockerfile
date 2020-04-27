FROM alpine:latest
RUN apk --no-cache add bash ncftp
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["bash", "/entrypoint.sh"]
