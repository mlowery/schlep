#!/usr/bin/env bash

if [[ $SCHLEP_HOOK_DEBUG == 1 ]]; then
    LOG_VERBOSITY=$_log_level_debug
    set -x
fi

echo hello