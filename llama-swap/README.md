# llama-swap (lif fork)

Custom [llama-swap](https://github.com/mostlygeek/llama-swap) image for
the lif RTX 3090 box. Hot-swaps six LLMs across three llama.cpp forks
(stock, `ik_llama.cpp`, `atomic-llama-cpp-turboquant`, `beellama.cpp`)
behind a single OpenAI-compatible endpoint on port 8020.

## Files

| File | Purpose |
|------|---------|
| `compose.yml` | Single `llama-swap` service, GPU-pinned, port 8020 |
| `Dockerfile` | Multi-stage build, overlays the 3 fork binaries onto upstream `llama-swap:unified-cuda` |
| `config-ik.yaml` | Active config — `ik-llama-server` for Qwen3.6, `atomic-llama-server` for Gemma-4 |
| `config-bee.yaml` | Alternate — `beellama` backend for Qwen3.6 |
| `*-server.sh` | One-line wrappers that set `LD_LIBRARY_PATH` per fork |
| `.env.example` | Template — copy to `.env` and fill in |
| `Makefile` | Convenience wrappers around `docker compose` |

## Prerequisites

Three locally-built parent images (date-tagged, pinned in Dockerfile):

```
atomic-llama-cpp:server-cuda-YYYY-MM-DD   # from ~/Git/atomic-llama-cpp-turboquant
ik-llama-cpp:server-cuda-YYYY-MM-DD       # from ~/Git/ik_llama.cpp
beellama:server-cuda-YYYY-MM-DD           # from ~/Git/beellama.cpp
```

Plus GGUF weights at `$MODEL_DIR` (default `/home/peteryu/llms`).

### Building ik-llama

```sh
cd ~/Git/ik_llama.cpp
git pull origin main
docker build \
  -f docker/ik_llama-cuda.Containerfile \
  --target server \
  --build-arg CUDA_DOCKER_ARCH='86-real' \
  --build-arg GGML_NATIVE=OFF \
  -t ik-llama-cpp:server-cuda-YYYY-MM-DD .
```

- Uses `docker/ik_llama-cuda.Containerfile` (CUDA 12.6, Ubuntu 24.04, ccache)
- Target `server` puts binary at `/app/llama-server`, libs at `/app/lib/`
- ccache is persistent — first build ~10 min, subsequent ~1-2 min
- After building, update the `FROM ik-llama-cpp:...` pin in `Dockerfile`

## Quick start

```sh
cp .env.example .env       # set HF_TOKEN, MODEL_DIR
make build                 # bake the unified image
make up                    # start
make smoke                 # list resident model IDs
```

Switch to the bee backend without editing `.env`:

```sh
make up CONFIG=config-bee.yaml
```

## Adding a model

1. Drop the GGUF in `$MODEL_DIR`.
2. Append a model block to `config-ik.yaml`. Reuse a macro where possible:

   ```yaml
   "MyQwenVariant":
     cmd: |
       ${qwen_base}
       -m /models/MyQwenVariant.gguf
       --mmproj /models/mmproj-MyQwenVariant.gguf
   ```

3. `make restart` — configs are bind-mounted, no rebuild needed.

Available macros in `config-ik.yaml`:

- `qwen_base` — ik-llama + preserve_thinking + threads + cache + MTP + sampling
- `gemma_mtp_engine` — atomic-llama + MTP head + turbo3 cache (no sampling)
- `gemma_sampling_creative` — temp 1.0 / top-k 64 / dry 0.4 set

## Adding a backend

Edit `Dockerfile` (add a `FROM ... AS X-source` and `COPY --from=X-source`),
write a wrapper script `X-llama-server.sh`, register it in the
`COPY ... RUN chmod +x ...` lines, then `make build`.

## Updating a pinned base image

The `Dockerfile` pins all four `FROM` refs to immutable tags (local images
are date-tagged, upstream uses `@sha256:`). When a sibling repo rebuilds
its `:server-cuda` floating tag, the date-tagged ref the Dockerfile uses
still points at the old layer — `make build` keeps working unchanged.

To adopt a new sibling build:

```sh
make pins                                          # see what drifted
# For ik-llama: rebuild with Containerfile (see Prerequisites)
# For others: docker tag <image>:server-cuda <image>:server-cuda-YYYY-MM-DD
# Then edit Dockerfile: bump the date suffix on the FROM line
make build && make smoke
```

For upstream (`ghcr.io/mostlygeek/llama-swap`): docker pull, then read
`make pins` for the new `sha256:` digest and update the `@sha256:` suffix
on its `FROM` line.

## Debugging

```sh
make argv     # show argv of the running upstream llama-server
              # — verifies macro expansion and quoting
make logs     # tail container logs
docker exec -it llama-swap bash
```

## Upstream

This fork lives at `alandy88/club-3090`. Upstream is `noonghunna/club-3090`;
the `llama-swap/` dir is lif-local and not intended for upstreaming.
