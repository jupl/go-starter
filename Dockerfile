FROM golang:alpine AS build
RUN apk add --no-cache git
RUN go get -u github.com/golang/dep/cmd/dep
RUN go get -u github.com/jteeuwen/go-bindata/...
WORKDIR /go/src/github.com/jupl/go-starter
ADD . .
RUN go generate ./...
RUN dep ensure
ARG PACKAGE
RUN go install ./cmd/$PACKAGE

FROM alpine
RUN apk --no-cache add ca-certificates
ARG PACKAGE
WORKDIR /app
COPY --from=build /go/bin/$PACKAGE ./package
ENTRYPOINT ["./package"]
