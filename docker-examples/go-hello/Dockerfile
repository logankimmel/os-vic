FROM golang:1.7
ADD . /go/src/go-hello
WORKDIR /go/src/go-hello
RUN cd /go/src/go-hello && go get ./...
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

FROM scratch
COPY --from=0 /go/src/go-hello/main /
CMD ["/main"]
EXPOSE 80
