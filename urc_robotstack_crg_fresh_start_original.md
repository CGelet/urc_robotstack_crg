# urc_robotstack_crg — Fresh Start (macOS + Docker Desktop, clean host)

**Scope**: Rebuild from scratch with a clean file tree, Docker-only installs (your macOS stays clean), GUI either via **xpra (web)** or **XQuartz (native X11)**. Works on Apple Silicon; falls back to software GL when needed.

---

## 0) Pre‑clean (macOS → Docker Desktop)
If you have any previous stack remnants, clean them out first so this is a true reset:

```bash
# Stop and remove any containers from older attempts (safe to run even if none exist)
docker compose down -v || true

# Optional but recommended: free builder cache and old images
docker builder prune -a -f
docker system prune -a -f
```

> This does not touch anything outside Docker Desktop’s disk image. Your macOS remains unchanged.

---

## 1) Create the repo & file tree (macOS shell)
```bash
mkdir -p urc_robotstack_crg/{config,ros,gz,cmu,scripts}
touch urc_robotstack_crg/{docker-compose.yml,.env,.gitignore,Makefile,README.md}
touch urc_robotstack_crg/config/cyclonedds.xml
touch urc_robotstack_crg/ros/Dockerfile
touch urc_robotstack_crg/gz/Dockerfile
touch urc_robotstack_crg/cmu/Dockerfile
touch urc_robotstack_crg/scripts/{mac_xquartz_prep.sh,up_xpra.sh,up_x11.sh}
```

---

## 2) Drop‑in file contents (copy verbatim)

### 2.1 `.env`
```env
TZ=America/New_York
ROS_DISTRO=humble
ROS_DOMAIN_ID=42
ROS_LOCALHOST_ONLY=0
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# Used by the XQuartz profile (xpra uses its own :100 virtual display)
DISPLAY=host.docker.internal:0
```

### 2.2 `.gitignore`
```gitignore
.DS_Store
*.log
```

### 2.3 `config/cyclonedds.xml`  (minimal)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CycloneDDS xmlns="https://cdds.io/config">
  <Domain id="any">
    <Discovery>
      <ParticipantIndex>auto</ParticipantIndex>
    </Discovery>
  </Domain>
</CycloneDDS>
```

### 2.4 `docker-compose.yml`
```yaml
version: "3.9"
name: urc_robotstack_crg

x-common-env: &common-env
  TZ: "${TZ}"
  ROS_DISTRO: "${ROS_DISTRO}"
  ROS_DOMAIN_ID: "${ROS_DOMAIN_ID}"
  ROS_LOCALHOST_ONLY: "${ROS_LOCALHOST_ONLY}"
  RMW_IMPLEMENTATION: "${RMW_IMPLEMENTATION}"
  CYCLONEDDS_URI: "file:///config/cyclonedds.xml"
  DISPLAY: "${DISPLAY}"      # used in x11 profile only

x-softgl: &softgl
  LIBGL_ALWAYS_SOFTWARE: "1"
  MESA_LOADER_DRIVER_OVERRIDE: "llvmpipe"
  GALLIUM_DRIVER: "llvmpipe"
  MESA_GL_VERSION_OVERRIDE: "3.3"
  MESA_GLSL_VERSION_OVERRIDE: "330"

networks:
  robotics:
    driver: bridge
    name: robotics

volumes:
  ros_ws:
  gz_ws:
  cmu_ws:
  shared_ws:
  bag_data:
  sim_assets:

services:
  # =============================
  # XQuartz profile (native X11)
  # =============================
  ros:
    container_name: ros
    build: { context: ./ros, dockerfile: Dockerfile }
    hostname: ros
    networks: [robotics]
    environment: { <<: [*common-env, *softgl] }
    volumes:
      - ros_ws:/work/ws
      - shared_ws:/work/shared
      - bag_data:/work/bags
      - ./config/cyclonedds.xml:/config/cyclonedds.xml:ro
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
    shm_size: "1g"
    ipc: "shareable"
    command: bash -lc "xterm & tail -f /dev/null"
    profiles: ["x11"]
    restart: unless-stopped

  gz:
    container_name: gz
    build: { context: ./gz, dockerfile: Dockerfile }
    hostname: gz
    networks: [robotics]
    environment: { <<: [*common-env, *softgl] }
    volumes:
      - gz_ws:/work/ws
      - sim_assets:/work/assets
      - shared_ws:/work/shared
      - ./config/cyclonedds.xml:/config/cyclonedds.xml:ro
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
    shm_size: "2g"
    ipc: "shareable"
    depends_on: [ros]
    command: bash -lc "xterm & tail -f /dev/null"
    profiles: ["x11"]
    restart: unless-stopped

  cmu:
    container_name: cmu
    build: { context: ./cmu, dockerfile: Dockerfile }
    hostname: cmu
    networks: [robotics]
    environment: { <<: [*common-env, *softgl] }
    volumes:
      - cmu_ws:/work/ws
      - shared_ws:/work/shared
      - bag_data:/work/bags
      - ./config/cyclonedds.xml:/config/cyclonedds.xml:ro
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
    shm_size: "1g"
    ipc: "shareable"
    depends_on: [ros]
    command: bash -lc "xterm & tail -f /dev/null"
    profiles: ["x11"]
    restart: unless-stopped

  # =============================
  # xpra profile (browser GUI)
  # =============================
  ros_xpra:
    container_name: ros_xpra
    build: { context: ./ros, dockerfile: Dockerfile }
    command: >
      bash -lc "xpra start :100 --bind-tcp=0.0.0.0:14501 --html=on --daemon=no --mdns=no
                --opengl=no --no-mmap --dpi=96 --start=fluxbox --start-child=xterm"
    ports: ["14501:14501"]
    environment:
      <<: [*common-env]
      DISPLAY: ":100"
    volumes:
      - ros_ws:/work/ws
      - shared_ws:/work/shared
      - bag_data:/work/bags
      - ./config/cyclonedds.xml:/config/cyclonedds.xml:ro
    networks: [robotics]
    shm_size: "1g"
    ipc: "shareable"
    profiles: ["xpra"]
    restart: unless-stopped

  gz_xpra:
    container_name: gz_xpra
    build: { context: ./gz, dockerfile: Dockerfile }
    command: >
      bash -lc "xpra start :100 --bind-tcp=0.0.0.0:14502 --html=on --daemon=no --mdns=no
                --opengl=no --no-mmap --dpi=96 --start=fluxbox --start-child=xterm"
    ports: ["14502:14502"]
    environment:
      <<: [*common-env]
      DISPLAY: ":100"
    volumes:
      - gz_ws:/work/ws
      - sim_assets:/work/assets
      - shared_ws:/work/shared
      - ./config/cyclonedds.xml:/config/cyclonedds.xml:ro
    networks: [robotics]
    shm_size: "2g"
    ipc: "shareable"
    profiles: ["xpra"]
    restart: unless-stopped

  cmu_xpra:
    container_name: cmu_xpra
    build: { context: ./cmu, dockerfile: Dockerfile }
    command: >
      bash -lc "xpra start :100 --bind-tcp=0.0.0.0:14503 --html=on --daemon=no --mdns=no
                --opengl=no --no-mmap --dpi=96 --start=fluxbox --start-child=xterm"
    ports: ["14503:14503"]
    environment:
      <<: [*common-env]
      DISPLAY: ":100"
    volumes:
      - cmu_ws:/work/ws
      - shared_ws:/work/shared
      - bag_data:/work/bags
      - ./config/cyclonedds.xml:/config/cyclonedds.xml:ro
    networks: [robotics]
    shm_size: "1g"
    ipc: "shareable"
    profiles: ["xpra"]
    restart: unless-stopped
```

### 2.5 `ros/Dockerfile`
```dockerfile
FROM ubuntu:jammy
ENV DEBIAN_FRONTEND=noninteractive

# Basics + GUI helpers
RUN apt-get update && apt-get install -y --no-install-recommends     locales tzdata curl gnupg2 lsb-release sudo nano git wget     python3-pip build-essential bash-completion     xauth x11-apps mesa-utils xpra fluxbox xterm  && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# ROS 2 Humble
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common &&     add-apt-repository universe && apt-get update &&     curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key       | gpg --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg &&     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg]     http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main"     > /etc/apt/sources.list.d/ros2.list &&     apt-get update && apt-get install -y --no-install-recommends       ros-humble-desktop       ros-humble-rmw-cyclonedds-cpp       ros-humble-tf2-tools       ros-humble-nav2-bringup  && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Dev user
RUN useradd -ms /bin/bash dev && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev
USER dev
WORKDIR /work/ws
SHELL ["/bin/bash","-lc"]
RUN echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc
```

### 2.6 `gz/Dockerfile`  (Gazebo Fortress via ros-gz)
```dockerfile
FROM ubuntu:jammy
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends     locales tzdata curl gnupg2 lsb-release sudo nano git wget     xauth x11-apps mesa-utils xpra fluxbox xterm  && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# ROS 2 repo + ros-gz for Humble (Fortress)
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common &&     add-apt-repository universe && apt-get update &&     curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key       | gpg --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg &&     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg]     http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main"     > /etc/apt/sources.list.d/ros2.list &&     apt-get update && apt-get install -y --no-install-recommends       ros-humble-ros-gz  && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN useradd -ms /bin/bash dev && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev
USER dev
WORKDIR /work/ws
SHELL ["/bin/bash","-lc"]
RUN echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc
# Launch Gazebo with:  ign gazebo <world>.sdf
```

### 2.7 `cmu/Dockerfile`  (customize packages as needed)
```dockerfile
FROM ubuntu:jammy
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends     locales tzdata curl gnupg2 lsb-release sudo nano git     python3-pip build-essential     xauth x11-apps xpra fluxbox xterm  && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key       | gpg --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg &&     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg]     http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main"     > /etc/apt/sources.list.d/ros2.list &&     apt-get update && apt-get install -y --no-install-recommends       ros-humble-desktop       ros-humble-navigation2 ros-humble-nav2-bringup       ros-humble-slam-toolbox  && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN useradd -ms /bin/bash dev && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev
USER dev
WORKDIR /work/ws
SHELL ["/bin/bash","-lc"]
RUN echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc
```

### 2.8 `scripts/mac_xquartz_prep.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
echo "Open XQuartz → Preferences → Security: check 'Allow connections from network clients'."
open -a XQuartz || true
sleep 2
xhost +127.0.0.1 >/dev/null 2>&1 || true
xhost +localhost  >/dev/null 2>&1 || true
echo "XQuartz ready. DISPLAY should be host.docker.internal:0"
```

### 2.9 `scripts/up_xpra.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
docker compose --profile xpra up -d --build
echo "Open:"
echo "  ROS: http://localhost:14501/"
echo "   GZ: http://localhost:14502/"
echo "  CMU: http://localhost:14503/"
```

### 2.10 `scripts/up_x11.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
export DISPLAY="${DISPLAY:-host.docker.internal:0}"
docker compose --profile x11 up -d --build
```

### 2.11 `Makefile`
```makefile
X11=DISPLAY=host.docker.internal:0

up-xpra:
	docker compose --profile xpra up -d --build

up-x11:
	$(X11) docker compose --profile x11 up -d --build

down:
	docker compose down

ros:
	docker exec -it ros bash

gz:
	docker exec -it gz bash

cmu:
	docker exec -it cmu bash

logs:
	docker compose logs -f --tail=200
```

---

## 3) Initialize the repo (macOS)
```bash
cd /path/to/urc_robotstack_crg
chmod +x scripts/*.sh
git init && git add -A && git commit -m "init urc_robotstack_crg"
```

---

## 4) Build & run

### Option A — **xpra (browser GUI; easiest)**
```bash
make up-xpra
```
Open:
- ROS → http://localhost:14501/
- GZ  → http://localhost:14502/
- CMU → http://localhost:14503/

> Blue Fluxbox desktop appears with **xterm auto‑started** in each container.

### Option B — **XQuartz (native X11)**
```bash
./scripts/mac_xquartz_prep.sh   # one-time to allow network clients
make up-x11
```
> Windows from containers will appear on macOS via XQuartz; xterm auto‑starts.

---

## 5) Quick checks (inside container xterm)
```bash
# Common
source /opt/ros/${ROS_DISTRO}/setup.bash

# RViz2 (ros container)
rviz2

# Gazebo (gz container, Fortress via ros-gz)
ign gazebo shapes.sdf -v 4
```

---

## 6) Inter‑container ROS 2 comms sanity
**Terminal A (ros):**
```bash
source /opt/ros/${ROS_DISTRO}/setup.bash
ros2 run demo_nodes_cpp talker
```

**Terminal B (cmu):**
```bash
source /opt/ros/${ROS_DISTRO}/setup.bash
ros2 run demo_nodes_cpp listener
```

You should see messages arriving in `cmu`. Also try `ros2 topic list` anywhere.

---

## 7) Common tasks (ROS workspaces)
All your code/data stays in Docker volumes:

- `ros_ws` → `/work/ws`  (ros)
- `gz_ws`  → `/work/ws`  (gz)
- `cmu_ws` → `/work/ws`  (cmu)
- `shared_ws` → `/work/shared` (visible to all)
- `bag_data` → `/work/bags`
- `sim_assets` → `/work/assets`

Examples:
```bash
# Record a bag from cmu
ros2 bag record -a -o /work/bags/test_bag

# Inspect from ros
ros2 bag info /work/bags/test_bag
```

---

## 8) Rebuild / reset lifecycle

- **Fast path** (rebuild changed pieces & (re)start):
  ```bash
  make up-xpra      # or: make up-x11
  ```

- **Clean rebuild** (after Dockerfile/compose edits):
  ```bash
  make down
  docker compose build --no-cache ros_xpra gz_xpra cmu_xpra   # or ros/gz/cmu for x11
  make up-xpra
  ```

- **Stop everything**:
  ```bash
  make down
  ```

- **Full reset including named volumes (⚠️ wipes data)**:
  ```bash
  docker compose down -v
  ```

- **Recreate only xpra services** (after tweaking xpra flags):
  ```bash
  docker compose up -d --force-recreate --no-deps ros_xpra gz_xpra cmu_xpra
  ```

---

## 9) Apple Silicon notes
If you hit an x86‑only dependency, force AMD64 emulation (slower but works):
```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 make up-xpra
```

OpenGL is set to software fallback (`llvmpipe`) by default for safety.

---

## 10) Troubleshooting quickies
- **xpra = blue desktop, no terminal** → Fluxbox right‑click → `xterm`, or restart service:
  ```bash
  docker compose up -d --force-recreate --no-deps ros_xpra gz_xpra cmu_xpra
  ```
- **XQuartz shows nothing** → Preferences → *Security* → ✔ “Allow connections from network clients”; run `./scripts/mac_xquartz_prep.sh`; ensure `DISPLAY=host.docker.internal:0` on macOS.
- **No ROS topics across containers** → same `ROS_DOMAIN_ID`, `ROS_LOCALHOST_ONLY=0`, all on `robotics` network.
- **Disk / input‑output errors** → free Docker disk:
  ```bash
  docker builder prune -a -f && docker system prune -a -f
  ```
  or increase Docker Desktop disk image size.

  ## Personal Notes
  You can start the xterms by the following
  ```bash
  docker compose exec ros_xpra bash -lc 'xpra control :100 start xterm'
  docker compose exec gz_xpra  bash -lc 'xpra control :100 start xterm'
  docker compose exec cmu_xpra bash -lc 'xpra control :100 start xterm'
  ```
  Run this for CMU error
  
  ```bash
  # 1) Stop everything & clear any leftovers
  pkill -9 -f "gzserver|gzclient|rviz2|ros2|spawn_entity.py|vehicleSimulator|visualizationTools|realTimePlot|joy_node" || true
  sudo rm -f /dev/shm/cyclonedds* /dev/shm/ros2_* /dev/shm/dds* /dev/shm/rt_* 2>/dev/null || true

  # 2) Keep SHM disabled (you already set this) and force CycloneDDS
  export CYCLONEDDS_URI='<CycloneDDS><Domain id="any"><SharedMemory><Enable>false</Enable></SharedMemory></Domain></CycloneDDS>'
  export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

  # 3) Pick a valid domain id
  export ROS_DOMAIN_ID=31
  echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"

  # 4) Re-source & launch
  source /opt/ros/humble/setup.bash
  source /work/ws/autonomous_exploration_development_environment/install/setup.bash
  ros2 launch vehicle_simulator system_garage.launch
  ```
  ```bash
  - RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
    - ROS_DOMAIN_ID=31
    - CYCLONEDDS_URI=<CycloneDDS><Domain id="any"><SharedMemory><Enable>false</Enable></SharedMemory></Domain></CycloneDDS>
  ```