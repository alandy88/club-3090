# llama-swap (lif fork)

Custom [llama-swap](https://github.com/mostlygeek/llama-swap) image for
the lif RTX 3090 box. Hot-swaps six LLMs across three llama.cpp forks
(stock, `ik_llama.cpp`, `atomic-llama-cpp-turboquant`, `beellama.cpp`)
behind a single OpenAI-compatible endpoint on port 8020.

The image also overlays a **pinned llama-swap release binary** over the
upstream base (see [Vendoring the llama-swap binary](#vendoring-the-llama-swap-binary)).
That binary is local-only and not committed, so **this image can only be
built on a host where the binary has been fetched** — a fresh clone
cannot `make build` until then.

## Files

| File | Purpose |
|------|---------|
| `compose.yml` | Single `llama-swap` service, GPU-pinned, port 8020 |
| `Dockerfile` | Multi-stage build; overlays the 3 fork binaries **and a pinned llama-swap binary** onto upstream `llama-swap:unified-cuda` |
| `config-ik.yaml` | Active config — `ik-llama-server` for Qwen3.6, `atomic-llama-server` for Gemma-4 |
| `config-bee.yaml` | Alternate — `beellama` backend for Qwen3.6 |
| `*-server.sh` | One-line wrappers that set `LD_LIBRARY_PATH` per fork |
| `vendor-llama-swap/llama-swap` | **Local-only** (not committed) — official llama-swap release binary, overlaid to run a newer version than the base ships. See [Vendoring the llama-swap binary](#vendoring-the-llama-swap-binary). |
| `.env.example` | Template — copy to `.env` and fill in |
| `Makefile` | Convenience wrappers around `docker compose` |

## Prerequisites

Three locally-built parent images (date-tagged, pinned in Dockerfile):

```
atomic-llama-cpp:server-cuda-YYYY-MM-DD   # from ~/Git/atomic-llama-cpp-turboquant
ik-llama-cpp:server-cuda-YYYY-MM-DD       # from ~/Git/ik_llama.cpp
beellama:server-cuda-YYYY-MM-DD           # from ~/Git/beellama.cpp
```

The vendored llama-swap binary (local-only — see
[Vendoring the llama-swap binary](#vendoring-the-llama-swap-binary)):

```
vendor-llama-swap/llama-swap              # official release binary, newer than the base bundles
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

### Vendoring the llama-swap binary

The upstream base image (`ghcr.io/mostlygeek/llama-swap:unified-cuda-YYYY-MM-DD`)
bakes in a specific llama-swap version that lags the latest release — its
daily rebuild bumps the bundled **llama.cpp**, not the **llama-swap**
binary. To run a newer llama-swap than the base ships (e.g. for a feature
only in a later release), overlay the official release binary:

```sh
cd ~/Git/club-3090/llama-swap
VER=219   # desired llama-swap release
curl -fSL -o /tmp/ls.tar.gz \
  "https://github.com/mostlygeek/llama-swap/releases/download/v${VER}/llama-swap_${VER}_linux_amd64.tar.gz"
mkdir -p vendor-llama-swap
tar -xzf /tmp/ls.tar.gz -C vendor-llama-swap llama-swap
chmod +x vendor-llama-swap/llama-swap
./vendor-llama-swap/llama-swap --version    # verify it reports vVER
```

The `Dockerfile`'s final line —
`COPY vendor-llama-swap/llama-swap /usr/local/bin/llama-swap` — overlays
it over the base's bundled binary (the web UI is embedded in the release
binary, so nothing else is needed).

**Consequences:**

- The image is **local-only**: `vendor-llama-swap/` is git-ignored and not
  committed, so a fresh clone cannot `make build` until the binary is
  re-fetched with the command above.
- The overlay **takes precedence** over the base's llama-swap, so bumping
  the base's `@sha256:` pin will not change the running llama-swap version
  while this overlay is present.
- To drop the overlay and fall back to the base's bundled llama-swap,
  delete that `COPY` line and `make build`.

When upstream eventually ships a base whose bundled llama-swap is new
enough, remove the overlay and pin the base normally instead.

## Quick start

```sh
cp .env.example .env       # set HF_TOKEN, MODEL_DIR
# fetch the vendored llama-swap binary first (see Vendoring section above)
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
on its `FROM` line. Note: while the `vendor-llama-swap` overlay is present,
bumping this pin changes only the bundled llama.cpp / stock `llama-server`,
**not** the llama-swap proxy version (see
[Vendoring the llama-swap binary](#vendoring-the-llama-swap-binary)).

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
