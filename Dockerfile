FROM nvidia/cuda:12.8.1-base-ubuntu20.04

ARG UID=1000
ARG GID=1000
ARG NAME="user"
ARG TZ="Asia/Taipei"

ENV INSTALLATION_TOOLS="apt-utils curl sudo software-properties-common"
ENV DEVELOPMENT_PACKAGES="python3.8 python3-pip"
ENV TOOL_PACKAGES="bash dos2unix git locales nano tree vim wget nvidia-container-toolkit openssh-server"
ENV LLM_TOOL_PACKAGES="ffmpeg cargo"
ENV USER=${NAME}
ENV TERM=xterm-256color

RUN DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y ${INSTALLATION_TOOLS} && \
    add-apt-repository ppa:git-core/ppa && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && \
    DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install ${DEVELOPMENT_PACKAGES} ${TOOL_PACKAGES} ${LLM_TOOL_PACKAGES}

RUN curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add - && \
    bash -lc 'distribution=$(. /etc/os-release; echo $ID$VERSION_ID)' && \
    bash -lc 'curl -s -L https://nvidia.github.io/nvidia-docker/${distribution}/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list'

# 官方安裝腳本
RUN curl -fsSL https://ollama.com/install.sh | sh

ENV OLLAMA_MODELS=/opt/ollama
RUN mkdir -p /opt/ollama && chown ${UID}:${GID} /opt/ollama

COPY ./projects/PodcastLLM/requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt

RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone
RUN sed -i 's/# en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen && \
    sed -i 's/# zh_TW.UTF-8/zh_TW.UTF-8/g' /etc/locale.gen && \
    sed -i 's/# zh_TW BIG5/zh_TW BIG5/g' /etc/locale.gen && \
    locale-gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN groupadd -g ${GID} -o ${NAME} && \
    useradd -u ${UID} -m -s /bin/bash -g ${GID} ${NAME} && \
    echo "${NAME} ALL = NOPASSWD: ALL" > /etc/sudoers.d/${NAME} && \
    chmod 0440 /etc/sudoers.d/${NAME} && \
    passwd -d ${NAME}

RUN mkdir -p /var/run/sshd && \
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's@^#\?AuthorizedKeysFile .*@AuthorizedKeysFile %h/.ssh/authorized_keys@' /etc/ssh/sshd_config

COPY ./scripts/.bashrc /home/${NAME}/.bashrc
COPY ./scripts/start.sh /usr/start.sh
COPY ./scripts/startup /usr/local/bin/startup
RUN dos2unix -ic /home/${NAME}/.bashrc | xargs dos2unix && \
    dos2unix -ic /usr/start.sh | xargs dos2unix && \
    dos2unix -ic /usr/local/bin/startup | xargs dos2unix && \
    chmod 644 /home/${NAME}/.bashrc && \
    chmod 755 /usr/start.sh && \
    chmod 755 /usr/local/bin/startup && \
    chown -R ${UID}:${GID} /home/${NAME}

COPY ./ssh_keys/ /tmp/ssh-keys/
RUN mkdir -p /home/${NAME}/.ssh && \
    touch /home/${NAME}/.ssh/authorized_keys && \
    if [ -d /tmp/ssh-keys ]; then \
      find /tmp/ssh-keys -type f -name '*.pub' -exec cat {} \; >> /home/${NAME}/.ssh/authorized_keys || true ; \
    fi && \
    chmod 700 /home/${NAME}/.ssh && \
    chmod 600 /home/${NAME}/.ssh/authorized_keys && \
    chown -R ${UID}:${GID} /home/${NAME}/.ssh

RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/start.sh && \
    sed -i 's/\r$//' /usr/start.sh && \
    awk 'NR==1{print; \
               print "sudo service ssh start || true"; \
               print "export OLLAMA_HOST=0.0.0.0:11434"; \
               print "export OLLAMA_MODELS=/opt/ollama"; \
               print "nohup ollama serve > /home/'"${NAME}"'/ollama.log 2>&1 &"; \
               next}1' /usr/start.sh > /tmp/start.sh && \
    mv /tmp/start.sh /usr/start.sh && \
    chmod 755 /usr/start.sh

RUN GRADIO_DIR=$(python3 -c "import gradio, pathlib; print(pathlib.Path(gradio.__file__).parent)") \
    && mkdir -p "$GRADIO_DIR" \
    && curl -L -o "$GRADIO_DIR/frpc_linux_amd64_v0.2" \
       https://cdn-media.huggingface.co/frpc-gradio-0.2/frpc_linux_amd64 \
    && chmod +x "$GRADIO_DIR/frpc_linux_amd64_v0.2"

EXPOSE 22
EXPOSE 11434

WORKDIR /home/${NAME}
CMD [ "/usr/start.sh" ]
