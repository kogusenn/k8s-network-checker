FROM alpine:3.9

RUN apk --update add bash bind-tools

COPY run.sh /usr/local/bin/network-checker

CMD ["network-checker"]
