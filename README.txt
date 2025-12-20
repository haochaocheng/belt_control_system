Belt Control System - Project Root Directory
=============================================

ACTIVE FILES (Keep in Root):
-----------------------------

Build Scripts:
- build-ubuntu24-apt.ps1    : Main build & deploy script (use: .\build-ubuntu24-apt.ps1 151)
- build-rk3588.ps1          : Cross-compilation for RK3588 (32 threads)
- build-base-image.ps1      : Build base Docker image separately
- build-tts-service-arm64.ps1 : Build TTS service
- build-ubuntu24-complete.ps1 : Complete build script
- build-and-deploy-188.ps1  : Quick deploy to device 188
- deploy-188-landscape.ps1  : Deploy landscape mode to 188
- build.ps1, build.bat      : Legacy build scripts

Run Scripts:
- run.ps1, run.bat          : Local run scripts
- run-155-x11.sh            : Run on device 155 with X11

Dockerfiles:
- Dockerfile.ubuntu24-base  : Base image (system dependencies + emoji fonts)
- Dockerfile.ubuntu24-apt   : Application layer (uses base image)
- Dockerfile                : Legacy dockerfile

Configuration:
- CMakeLists.txt            : Main CMake configuration
- config.ini.example        : Configuration template
- eglfs_config_155.json     : Display configuration for device 155
- .gitignore                : Git ignore rules

Cache Files:
- .docker_base_cache.json   : Base image build cache
- .docker_app_cache.json    : Application image build cache
- .docker_build_cache.json  : General build cache

Databases (Runtime Data):
- alarm_history.db          : Alarm history database
- protection_config.db      : Protection configuration database


ARCHIVED FILES:
---------------
Location: archive/old_docs/    - All .md and .txt documentation files
Location: archive/old_images/  - All .tar Docker image files
Location: archive/old_logs/    - All .log files


PROJECT STRUCTURE:
------------------
src/          - Source code (C++, QML)
libs/         - Third-party libraries (sherpa-onnx, pjsip, etc.)
docker/       - Docker build configurations
cmake/        - CMake helper scripts
build_rk3588/ - Build output directory
archive/      - Archived files (docs, logs, images)


QUICK START:
------------
1. Build and deploy to device 151:
   .\build-ubuntu24-apt.ps1 151

2. Build and deploy to device 188:
   .\build-ubuntu24-apt.ps1 188

3. Build base image separately (first time or when dependencies change):
   .\build-base-image.ps1


NOTES:
------
- First build will download ~200MB dependencies (takes 5-10 min)
- Subsequent builds only take 1-2 minutes (cached)
- Compiled with 32 threads for fast builds
- Emoji fonts included in base image for QML display
