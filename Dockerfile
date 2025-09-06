FROM golang:1.25-alpine AS builder

WORKDIR /app
COPY . .
RUN apk add --no-cache \
  git \
  curl \
  protobuf \
  build-base

RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -v -ldflags="-s -w" -o ./dist/novakey

ENV PATH="/go/bin:${PATH}"

FROM alpine:latest

WORKDIR /root/
COPY --from=builder /app/dist /app/dist

EXPOSE 5000
ENTRYPOINT ["/app/dist/novakey"]