FROM nvidia/cuda:12.8.1-base-ubuntu20.04

ARG UID=1000
ARG GID=1000
ARG NAME="user"
ARG TZ="Asia/Taipei"

ENV INSTALLATION_TOOLS apt-utils \
        curl \
        sudo \
        software-properties-common

ENV DEVELOPMENT_PACKAGES python3.8 \
        python3-pip

ENV TOOL_PACKAGES bash \
        dos2unix \
        git \
        locales \
        nano \
        tree \
        vim \
        wget \
        nvidia-container-toolkit 

ENV LLM_TOOL_PACKAGES ffmpeg \
cargo


ENV USER ${NAME}
ENV TERM xterm-256color

# install system packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y ${INSTALLATION_TOOLS} && \
    add-apt-repository ppa:git-core/ppa && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && \
    DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install ${DEVELOPMENT_PACKAGES} ${TOOL_PACKAGES} ${LLM_TOOL_PACKAGES}

# Install nvidia driver packages
RUN curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
RUN distribution=$(. /etc/os-release;echo $ID$VERSION_ID) && \
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list

# install python libraries
COPY ./projects/PodcastLLM/requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt

# setup time zone
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# add support of locale zh_TW
RUN sed -i 's/# en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen && \
    sed -i 's/# zh_TW.UTF-8/zh_TW.UTF-8/g' /etc/locale.gen && \
    sed -i 's/# zh_TW BIG5/zh_TW BIG5/g' /etc/locale.gen && \
    locale-gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# add non-root user account
RUN groupadd -g ${GID} -o ${NAME} && \
    useradd -u ${UID} -m -s /bin/bash -g ${GID} ${NAME} && \
    echo "${NAME} ALL = NOPASSWD: ALL" > /etc/sudoers.d/${NAME} && \
    chmod 0440 /etc/sudoers.d/${NAME} && \
    passwd -d ${NAME}

# add scripts and setup permissions
COPY ./scripts/.bashrc /home/${NAME}/.bashrc
COPY ./scripts/start.sh /usr/start.sh
COPY ./scripts/startup /usr/local/bin/startup
RUN dos2unix -ic /home/${NAME}/.bashrc | xargs dos2unix && \
    dos2unix -ic /usr/start.sh | xargs dos2unix && \
    dos2unix -ic /usr/local/bin/startup | xargs dos2unix && \
    chmod 644 /home/${NAME}/.bashrc && \
    chmod 755 /usr/start.sh && \
    chmod 755 /usr/local/bin/startup

USER ${NAME}

WORKDIR /home/${NAME}

CMD [ "/usr/start.sh" ]
