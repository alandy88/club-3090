#!/bin/sh
LD_LIBRARY_PATH=/opt/atomic:/usr/local/cuda/lib64 exec /opt/atomic/llama-server "$@"
