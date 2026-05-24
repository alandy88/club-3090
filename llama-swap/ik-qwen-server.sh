#!/bin/sh
exec ik-llama-server "$@" --chat-template-kwargs '{"preserve_thinking":true}'
