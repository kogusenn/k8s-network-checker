FROM alpine:3.9

RUN apk --update add bash bind-tools

COPY run.sh network-checker

CMD ["network-checker"]
