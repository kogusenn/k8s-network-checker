FROM alpine:3.9

ENV KUBECTL_VERSION 1.14.1

RUN apk --update add bash bind-tools curl

RUN curl -L https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

COPY run.sh /usr/local/bin/network-checker

CMD ["network-checker"]
