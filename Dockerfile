# Prints "hello world" once a second, ten times, then exits 0.
# The ten-second behaviour lives here. The workflow only observes it.
FROM busybox:1.37.0

CMD ["sh", "-c", "i=1; while [ \"$i\" -le 10 ]; do echo 'hello world'; sleep 1; i=$((i+1)); done"]
