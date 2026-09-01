FROM ubuntu:26.04
CMD ["/bin/sh", "-c", "echo 'Hello, world from Ubuntu 26.04'; echo 'this line came from stderr' >&2"]
