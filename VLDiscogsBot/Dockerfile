# Build context must be the parent directory containing all packages:
#   docker build -t vldiscogsbot -f VLDiscogsBot/Dockerfile .
#
# For Railway: push all package repos into one repo as subdirectories,
# set the Dockerfile path to VLDiscogsBot/Dockerfile in Railway settings.

FROM swift:6.2-noble AS builder
WORKDIR /build

COPY VLDiscogsBot       VLDiscogsBot/
COPY VLDiscogsClient    VLDiscogsClient/
COPY VLNetworkingClient VLNetworkingClient/
COPY VLOAuthFlowCoordinator VLOAuthFlowCoordinator/
COPY VLDebugLogger      VLDebugLogger/

WORKDIR /build/VLDiscogsBot
RUN swift build -c release --product App 2>&1

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libxml2 \
    libz3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/lib/swift /usr/lib/swift

WORKDIR /app
COPY --from=builder /build/VLDiscogsBot/.build/release/App .

EXPOSE 8080
CMD ["./App"]
