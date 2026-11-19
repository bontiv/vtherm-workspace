# Python 3.14 is required by Home Assistant 2026.11 (see versatile_thermostat/requirements_dev.txt).
FROM mcr.microsoft.com/devcontainers/python:3.14-bookworm

# ffmpeg and libturbojpeg: needed by the stream and camera components of Home Assistant (same packages as the Versatile Thermostat image).
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends ffmpeg libturbojpeg0-dev jq \
    && rm -rf /var/lib/apt/lists/*
