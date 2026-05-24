# =============================================================================
# Custom llama-swap unified image with 4 server engines:
#   - llama-server        (stock llama.cpp, from unified base)
#   - ik-llama-server     (ik_llama.cpp, locally built)
#   - atomic-llama-server (atomic-llama-cpp-turboquant, for Gemma 4 MTP)
#   - bee-llama-server    (beellama.cpp, DFlash + TurboQuant)
# =============================================================================

FROM atomic-llama-cpp:server-cuda AS atomic-source
FROM ik-llama-cpp:server-cuda AS ik-source
FROM beellama:server-cuda AS bee-source

FROM ghcr.io/mostlygeek/llama-swap:unified-cuda

# Overlay locally built ik-llama-server with its own libs
COPY --from=ik-source /llama-server /opt/ik/llama-server
COPY --from=ik-source /usr/local/lib/libggml.so /opt/ik/
COPY --from=ik-source /usr/local/lib/libllama.so /opt/ik/
COPY --from=ik-source /usr/local/lib/libmtmd.so /opt/ik/

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
