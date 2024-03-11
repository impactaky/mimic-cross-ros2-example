FROM --platform=${BUILDPLATFORM} impactaky/mc-ubuntu22.04-${TARGETARCH}-host:2.3.0 AS mimic-host

# ==============================================================================
FROM ros:humble-ros-core-jammy AS native

RUN rm /etc/apt/apt.conf.d/docker-clean
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-rosdep \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init

# ==============================================================================
FROM native AS mimiced

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ccache \
        clangd \
        g++ \
        gcc \
        git \
        make \
        python3-colcon-common-extensions \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mimic-host / /mimic-cross
RUN /mimic-cross/mimic-cross.deno/setup.sh

# ==============================================================================
FROM mimiced AS dev

RUN rm /etc/apt/apt.conf.d/docker-clean \
    rm -f /etc/apt/apt.conf.d/docker-clean

# ==============================================================================
FROM mimiced AS build

COPY src /ros_ws/src
WORKDIR /ros_ws
RUN apt-get update \
    && rosdep update \
    && rosdep install -i --from-path src --rosdistro humble -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN /ros_entrypoint.sh colcon build

# ==============================================================================
FROM native AS release

COPY src /ros_ws/src
WORKDIR /ros_ws
RUN apt-get update \
    && rosdep update \
    && rosdep install -i --from-path src --rosdistro humble -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /ros_ws/install /ros_ws/install
