FROM golang:alpine AS build
RUN apk add --no-cache git
RUN go get -u github.com/golang/dep/cmd/dep
RUN go get -u github.com/jteeuwen/go-bindata/...
WORKDIR /go/src/github.com/jupl/go-starter
ADD . .
RUN go generate ./...
RUN dep ensure
ARG BIN
RUN go install ./cmd/$BIN

FROM alpine
RUN apk --no-cache add ca-certificates
ARG BIN
WORKDIR /app
COPY --from=build /go/bin/$BIN ./start
ENTRYPOINT ["./start"]
