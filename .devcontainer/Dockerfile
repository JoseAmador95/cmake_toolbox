FROM ubuntu:noble

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get -y install --no-install-recommends \
    ca-certificates gpg wget \
    && test -f /usr/share/doc/kitware-archive-keyring/copyright \
    || wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
    | gpg --dearmor - \
    | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ noble main" \
    | tee /etc/apt/sources.list.d/kitware.list >/dev/null \
    && apt-get update && apt-get -y install --no-install-recommends \
    pipx \
    cmake \
    git \
    clang \
    clang-format \
    clang-tidy \
    ruby-dev \
    jq \
    gcovr \
    build-essential \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

RUN pipx ensurepath \
    && pipx install gersemi