FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod main.go ./
RUN go mod tidy && CGO_ENABLED=0 go build -o /tailscale-proxy .

FROM alpine:latest

RUN apk add --no-cache ca-certificates

COPY --from=builder /tailscale-proxy /tailscale-proxy

CMD ["/tailscale-proxy"]