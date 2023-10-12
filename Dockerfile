FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV OUTDIR=/packages

COPY . /build
WORKDIR /build

RUN apt update && apt install -y gcc make autoconf libtool libxtables-dev pkg-config curl ruby
RUN gem install fpm
RUN ./build.sh
