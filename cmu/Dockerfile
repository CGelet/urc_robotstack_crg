FROM ubuntu:jammy
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales tzdata curl gnupg2 lsb-release sudo nano git \
    python3-pip build-essential \
    xauth x11-apps xpra fluxbox xterm \
 && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
      | gpg --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
    http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
    > /etc/apt/sources.list.d/ros2.list && \
    apt-get update && apt-get install -y --no-install-recommends \
      ros-humble-desktop \
      ros-humble-navigation2 ros-humble-nav2-bringup \
      ros-humble-slam-toolbox \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN useradd -ms /bin/bash dev && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev
USER dev
WORKDIR /work/ws
SHELL ["/bin/bash","-lc"]
RUN echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc