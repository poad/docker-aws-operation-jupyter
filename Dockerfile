ARG UBUNTU_CODENAME="jammy"

ARG NODE_VERSION="18.x"
ARG LLVM_VERSION=16
ARG PYTHON_VERSION=3.11

ARG USER_NAME="jupyter"
ARG USER_HOME="/home/${USER_NAME}"

FROM buildpack-deps:${UBUNTU_CODENAME} AS downloader

ARG NODE_VERSION
RUN set -eux; \
  ARCH="$(dpkg --print-architecture)"; \
  case "${ARCH}" in \
  aarch64|arm64) \
    URL='https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip'; \
    ;; \
  amd64|x86_64) \
    URL='https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip'; \
    ;; \
  *) \
    echo "Unsupported arch: ${ARCH}"; \
    exit 1; \
    ;; \
  esac \
 && curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py \
 && curl -sSLo /tmp/llvm-snapshot.gpg.key https://apt.llvm.org/llvm-snapshot.gpg.key \
 && curl -sLo /tmp/setup_nodejs.sh "https://deb.nodesource.com/setup_${NODE_VERSION}" \
 && curl -sSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o /tmp/git-completion.bash \
 && curl -sSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh -o /tmp/_git \
 && curl -sSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh -o /tmp/git-prompt.sh \
 && git clone --recursive https://github.com/sorin-ionescu/prezto.git /tmp/prezto \
 && git clone https://github.com/zsh-users/zsh-completions.git /tmp/zsh-completions \
 && curl -sSLo /tmp/awscliv2.zip "${URL}" \
 && rm -rf /tmp/prezto/modules/prompt/external/powerlevel9k/docker /tmp/zsh-completions/.git /tmp/prezto/.git $/tmp/prezto/modules/autosuggestions/external/Dockerfile

FROM buildpack-deps:${UBUNTU_CODENAME}-curl AS base

LABEL maintainer="Kenji Saito<ken-yo@mbr.nifty.com>"

ARG USER_NAME
ARG USER_HOME

# Default to UTF-8 file.encoding
ENV LANG C.UTF-8

ARG USER_NAME
ARG USER_HOME

ARG LLVM_VERSION
ARG PYTHON_VERSION
ARG UBUNTU_CODENAME

ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV PATH="${PATH}:${JAVA_HOME}/bin"

USER root

WORKDIR /tmp

COPY --from=downloader /tmp/llvm-snapshot.gpg.key /tmp/llvm-snapshot.gpg.key
COPY --chown=1000:1000 requirements.txt /tmp/requirements.txt
COPY --from=downloader /tmp/setup_nodejs.sh /tmp/setup_nodejs.sh
COPY --from=downloader /tmp/get-pip.py /tmp/get-pip.py
COPY --from=downloader /tmp/awscliv2.zip /tmp/awscliv2.zip

ENV CC="/usr/bin/clang-${LLVM_VERSION}"
ENV CXX="/usr/bin/clang++-${LLVM_VERSION}"

ENV CXXFLAGS="-stdlib=libstdc++"
ENV LDLIBS="-lstdc++"

ARG DEPENDENCIES="\
  autoconf \
  automake \
  bzip2 \
  dpkg-dev \
  file \
  gcc \
  clang-${LLVM_VERSION} \
  clang++-${LLVM_VERSION} \
  lld-${LLVM_VERSION} \
  git \
  figlet \
  imagemagick \
  libbz2-dev \
  libc6-dev \
  libcurl4-openssl-dev \
  libdb-dev \
  libevent-dev \
  libffi-dev \
  libgdbm-dev \
  libglib2.0-dev \
  libgmp-dev \
  libjpeg-dev \
  libkrb5-dev \
  liblzma-dev \
  libmagickcore-dev \
  libmagickwand-dev \
  libmaxminddb-dev \
  libncurses5-dev \
  libncursesw5-dev \
  libpng-dev \
  libpq-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  libtool \
  libwebp-dev \
  libxml2-dev \
  libxslt-dev \
  libyaml-dev \
  libzmq3-dev \
  make \
  nodejs \
  patch \
  python${PYTHON_VERSION} \
  python${PYTHON_VERSION}-dev \
  python${PYTHON_VERSION}-distutils \
  libpython${PYTHON_VERSION}-dev \
  unzip \
  xz-utils \
  zlib1g-dev \
  tk-dev \
  uuid-dev"

RUN cat /tmp/llvm-snapshot.gpg.key | apt-key add - \
 && echo "deb http://apt.llvm.org/${UBUNTU_CODENAME}/ llvm-toolchain-${UBUNTU_CODENAME}-${LLVM_VERSION} main" >> /etc/apt/sources.list.d/llvm-toolchain.list \
 && rm -rf /var/lib/apt/lists/* \
 && apt-get update -qq \
 && apt-get full-upgrade -qqy \
 && apt-get install --no-install-recommends -qqy ca-certificates gnupg2 binutils apt-utils software-properties-common \
 && if ! "${UBUNTU_CODENAME}" == "jammy"; then add-apt-repository ppa:git-core/ppa -y; fi \
 && add-apt-repository ppa:deadsnakes/ppa -y \
 && apt-get install -qqy --no-install-recommends zsh \
 && chmod +x /tmp/setup_nodejs.sh \
 && /tmp/setup_nodejs.sh \
 && apt-get update -qq \
 && apt-get install -qqy --no-install-recommends ${DEPENDENCIES} \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists \
 && rm -rf /tmp/llvm-snapshot.gpg.key /tmp/setup_nodejs.sh \
 && unzip awscliv2.zip \
 && ./aws/install

RUN update-alternatives --install "/usr/bin/python3" "python3" "/usr/bin/python${PYTHON_VERSION}" 31000 \
 && update-alternatives --install "/usr/bin/python" "python" "/usr/bin/python3" 31000 \
 && python /tmp/get-pip.py --no-cache-dir \
 && rm -f /tmp/get-pip.py \
 && pip3 install --no-cache-dir -U pip \
 && pip install --no-cache-dir -U setuptools boto3  \
 && npm -g i npm \
 && npm -g i yarn configurable-http-proxy

RUN pip install --no-cache-dir -r /tmp/requirements.txt \
 && rm -f /tmp/requirements.txt \
 && python -m bash_kernel.install --sys-prefix \
 && jupyter serverextension enable --py jupyterlab --sys-prefix \
 && jupyter nbextension enable --py widgetsnbextension \
 && npm -g i tslab \
 && tslab install
 
RUN groupadd -g 1000 "${USER_NAME}" \
 && useradd -g 1000 -l -m -s /usr/bin/zsh -u 1000 "${USER_NAME}"

USER ${USER_NAME}

ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8 "
ENV PATH="${PATH}:/usr/local/bin"

WORKDIR /tmp

RUN jupyter notebook --generate-config \
 && mkdir -p "${USER_HOME}/.jupyter" \
 && mkdir -p "${USER_HOME}/notebook" \
 && chown -R "${USER_NAME}:${USER_NAME}" "${USER_HOME}"

COPY --chown=1000:1000 jupyter_notebook_config.py ${USER_HOME}/.jupyter/jupyter_notebook_config.py
COPY --chown=1000:1000 setup.zsh ${USER_HOME}/setup.zsh
COPY --chown=1000:1000 assets/zshrc /tmp/zshrc
COPY --chown=1000:1000 assets/package.json ${USER_HOME}/notebook/package.json
COPY --chown=1000:1000 assets/yarn.lock ${USER_HOME}/notebook/yarn.lock
COPY --chown=1000:1000 assets/tsconfig.json ${USER_HOME}/notebook/tsconfig.json
COPY --chown=1000:1000 --from=downloader /tmp/git-completion.bash ${USER_HOME}/.zsh/git-completion.bash
COPY --chown=1000:1000 --from=downloader /tmp/_git ${USER_HOME}/.zsh/_git
COPY --chown=1000:1000 --from=downloader /tmp/git-prompt.sh ${USER_HOME}/.zsh/git-prompt.sh
COPY --chown=1000:1000 --from=downloader /tmp/prezto ${USER_HOME}/.zprezto
COPY --chown=1000:1000 --from=downloader /tmp/zsh-completions ${USER_HOME}/.zsh-completions


FROM base AS release

ARG USER_NAME
ARG USER_HOME

USER ${USER_NAME}

WORKDIR ${USER_HOME}

RUN chmod 744 $HOME/setup.zsh \
 && $HOME/setup.zsh \
 && rm -rf setup.zsh \
 && ls -al \
 && pwd

RUN rm -rf $HOME/.zprezto/runcoms/zshrc \
 && mkdir -p $HOME/.zprezto/runcoms \
 && cat /tmp/zshrc > $HOME/.zprezto/runcoms/zshrc \
 && mv .zpreztorc .zpreztorc.bak \
 && sed -e "s/'sorin'/'redhat'/g" .zpreztorc.bak > .zpreztorc \
 && rm -rf .zpreztorc.bak /tmp/zshrc

WORKDIR ${USER_HOME}/notebook

RUN mkdir -p ${USER_HOME}/.npm \
 && npm config set prefix=${USER_HOME}/.npm

ENV PATH=${USER_HOME}/.npm/bin:$PATH \
    SHELL=/usr/bin/zsh

HEALTHCHECK CMD [ "npm", "--version" ]

EXPOSE 8888

SHELL [ "/usr/bin/zsh" ]

CMD ["jupyter", "lab"]
