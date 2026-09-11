FROM alpine:3.20
RUN apk add --no-cache curl jq ca-certificates tzdata
COPY check.sh entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/check.sh /usr/local/bin/entrypoint.sh
CMD ["/usr/local/bin/entrypoint.sh"]