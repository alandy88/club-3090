# =============================================================================
# Custom llama-swap unified image with 4 server engines:
#   - llama-server        (stock llama.cpp, from unified base)
#   - ik-llama-server     (ik_llama.cpp, locally built)
#   - atomic-llama-server (atomic-llama-cpp-turboquant, for Gemma 4 MTP)
#   - bee-llama-server    (beellama.cpp, DFlash + TurboQuant)
#
# Base images are pinned to immutable refs for reproducibility:
#   - Local images use date-suffixed tags (separate from the floating
#     :server-cuda tag the sibling repo writes). Re-tag and update here
#     after rebuilding a sibling fork; `make pins` shows drift.
#   - Upstream is pinned to both the date-tagged variant AND its @sha256
#     digest, so a tag-rewrite by upstream would fail-loud.
# =============================================================================

FROM atomic-llama-cpp:server-cuda-2026-05-19 AS atomic-source
FROM ik-llama-cpp:server-cuda-2026-05-28-v2 AS ik-source
FROM beellama:server-cuda-2026-05-18 AS bee-source

FROM ghcr.io/mostlygeek/llama-swap:unified-cuda-2026-05-21@sha256:0c954d3d9813369248f2245d6c29fbb6b49ac7c64052702a6ddf07f9f5d4c9b2

# Overlay locally built ik-llama-server with its own libs
COPY --from=ik-source /app/llama-server /opt/ik/llama-server
COPY --from=ik-source /app/lib/libggml.so /opt/ik/
COPY --from=ik-source /app/lib/libllama.so /opt/ik/
COPY --from=ik-source /app/lib/libmtmd.so /opt/ik/

# Copy atomic fork binary + all shared libs
COPY --from=atomic-source /app/llama-server /opt/atomic/llama-server
COPY --from=atomic-source /app/*.so* /opt/atomic/

# Copy beellama fork binary + all shared libs (dynamic backends)
COPY --from=bee-source /app/llama-server /opt/bee/llama-server
COPY --from=bee-source /app/*.so* /opt/bee/

# Install wrapper scripts
COPY ik-llama-server.sh /usr/local/bin/ik-llama-server
COPY atomic-llama-server.sh /usr/local/bin/atomic-llama-server
COPY bee-llama-server.sh /usr/local/bin/bee-llama-server
RUN chmod +x /usr/local/bin/ik-llama-server /usr/local/bin/atomic-llama-server /usr/local/bin/bee-llama-server
