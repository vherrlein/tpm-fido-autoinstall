FROM docker.io/alpine/git:latest AS importer

WORKDIR /src

RUN git clone https://github.com/psanford/tpm-fido.git /src


FROM docker.io/golang:alpine AS build

WORKDIR /src

COPY --from=importer /src /src

RUN go build -o /bin/tpm-fido


FROM scratch
COPY --from=build /bin/tpm-fido /
ENTRYPOINT ["/tpm-fido"]