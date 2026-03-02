FROM alpine:3.23

LABEL maintainer="Network Theory Applied Research Institute"
LABEL version="1.5.0"
LABEL description="NTARI OS v1.5 build environment — Alpine 3.23 + alpine-sdk"

# Install build tools for Alpine ISO generation
# Uses alpine-make-vm-image / mkimage approach (proper boot — not custom SquashFS)
RUN apk add --no-cache \
    alpine-sdk \
    build-base \
    apk-tools \
    alpine-conf \
    xorriso \
    squashfs-tools \
    mtools \
    dosfstools \
    grub \
    grub-efi \
    grub-bios \
    syslinux \
    bash \
    make \
    git \
    wget \
    curl \
    sudo \
    openssl \
    abuild

# Create build user with abuild group (required for Alpine package building)
RUN adduser -D -G abuild builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    addgroup builder wheel

# Set up abuild keys for package signing
USER builder
RUN abuild-keygen -a -i -n

USER root

# Add community and testing repositories for build tools
RUN cat > /etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/v3.23/main
https://dl-cdn.alpinelinux.org/alpine/v3.23/community
https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

RUN apk update

# Trust the alpine-ros APK signing key (SEQSENSE, seqsense.org).
# Written inline — no wget needed, key never changes for this repo.
# Key: builder@alpine-ros-experimental.rsa.pub
COPY <<'EOF' /etc/apk/keys/builder@alpine-ros-experimental.rsa.pub
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnSO+a+rIaTorOowj3c8e
5St89puiGJ54QmOW9faDsTcIWhycl4bM5lftp8IdcpKadcnaihwLtMLeaHNJvMIP
XrgEEoaPzEuvLf6kF4IN8HJoFGDhmuW4lTuJNfsOIDWtLBH0EN+3lPuCPmNkULeo
iS3Sdjz10eB26TYiM9pbMQnm7zPnDSYSLm9aCy+gumcoyCt1K1OY3A9E3EayYdk1
9nk9IQKA3vgdPGCEh+kjAjnmVxwV72rDdEwie0RkIyJ/al3onRLAfN4+FGkX2CFb
a17OJ4wWWaPvOq8PshcTZ2P3Me8kTCWr/fczjzq+8hB0MNEqfuENoSyZhmCypEuy
ewIDAQAB
-----END PUBLIC KEY-----
EOF

# Add alpine-ros repos (SEQSENSE): backports + jazzy ROS packages
# Repo is on CloudFront (S3-backed) — always reachable.
RUN echo "https://alpine-ros.seqsense.org/v3.23/backports" >> /etc/apk/repositories \
    && echo "https://alpine-ros.seqsense.org/v3.23/ros/jazzy" >> /etc/apk/repositories \
    && apk update

WORKDIR /build

# Grant builder sudo access with NOPASSWD for privileged operations (mkimage, mount, etc.)
RUN echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER builder

CMD ["/bin/bash"]
