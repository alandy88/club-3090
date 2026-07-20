# =============================================================================
# Custom llama-swap unified image with 3 server engines:
#   - llama-server        (stock llama.cpp, from unified base)
#   - ik-llama-server     (ik_llama.cpp, locally built)
#   - bee-llama-server    (beellama.cpp, DFlash + TurboQuant)
#
# Base images are pinned to immutable refs for reproducibility:
#   - Local images use date-suffixed tags (separate from the floating
#     :server-cuda tag the sibling repo writes). Re-tag and update here
#     after rebuilding a sibling fork; `make pins` shows drift.
#   - Upstream is pinned to both the date-tagged variant AND its @sha256
#     digest, so a tag-rewrite by upstream would fail-loud.
# =============================================================================

FROM ik-llama-cpp:server-cuda-2026-07-21 AS ik-source
FROM beellama:server-cuda-2026-06-06 AS bee-source

FROM ghcr.io/mostlygeek/llama-swap:unified-cuda-2026-05-21@sha256:0c954d3d9813369248f2245d6c29fbb6b49ac7c64052702a6ddf07f9f5d4c9b2

# Overlay locally built ik-llama-server with its own libs
COPY --from=ik-source /app/llama-server /opt/ik/llama-server
COPY --from=ik-source /app/lib/libggml.so /opt/ik/
COPY --from=ik-source /app/lib/libllama.so /opt/ik/
COPY --from=ik-source /app/lib/libmtmd.so /opt/ik/

# Copy beellama fork binary + all shared libs (dynamic backends)
COPY --from=bee-source /app/llama-server /opt/bee/llama-server
COPY --from=bee-source /app/*.so* /opt/bee/

# Install wrapper scripts
COPY ik-llama-server.sh /usr/local/bin/ik-llama-server
COPY bee-llama-server.sh /usr/local/bin/bee-llama-server
RUN chmod +x /usr/local/bin/ik-llama-server /usr/local/bin/bee-llama-server

# Overlay official llama-swap v219 binary over the base image's v217.
# Adds the new routing backend / request collation (PR #790, in v218+).
# Source: github.com/mostlygeek/llama-swap releases/v219/llama-swap_219_linux_amd64.tar.gz
#   sha256(tarball)=e8eb79e1b03ea6db912d4dcc9370313143e6b9a4b3850c9127de8f74b182d44e
# UI is embedded in the binary; revert by deleting this COPY to fall back to base v217.
COPY vendor-llama-swap/llama-swap /usr/local/bin/llama-swap
