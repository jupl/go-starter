# Set up
FROM golang:alpine AS base
RUN apk add --no-cache git make
WORKDIR /go/src/github.com/jupl/go-starter
ADD . .
RUN make

# Run tests
FROM base AS test
RUN make test

# Build binary
FROM base AS build
ARG PACKAGE
RUN make install PACKAGE=$PACKAGE

# Final destination
FROM alpine AS release
RUN apk --no-cache add ca-certificates
ARG PACKAGE
WORKDIR /app
COPY --from=build /go/bin/$PACKAGE ./package
ENTRYPOINT ["./package"]
