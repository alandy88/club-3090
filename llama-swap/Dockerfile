# =============================================================================
# Custom llama-swap unified image with 3 server engines:
#   - llama-server        (stock llama.cpp, from unified base — 1f368f3, 2026-08-13)
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

FROM ik-llama-cpp:server-cuda-2026-08-14-43afea4 AS ik-source
FROM beellama:server-cuda-2026-06-06 AS bee-source

FROM ghcr.io/mostlygeek/llama-swap:unified-cuda-2026-08-13@sha256:6939af87bbf6ee5a9410eb64f78002f8d583c3379fed11807c9f3f1a2d09e028

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

# No vendored llama-swap overlay: the 2026-08-13 base already ships v249,
# which is newer than the v228 binary we used to overlay onto the old v217
# base. Re-adding the COPY would DOWNGRADE the proxy. The routing backend /
# request collation that motivated the overlay (PR #790, v218+) is included.
