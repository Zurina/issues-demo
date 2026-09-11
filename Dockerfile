# sleep must outlast the workflow's 10s observation window (see hello-world-container.yml)
FROM alpine:3.20
CMD ["sh", "-c", "echo hello world && sleep 30"]
