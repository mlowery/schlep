#!/usr/bin/env bash

# Some functions borrowed from DevStack (https://github.com/openstack-dev/devstack)

# Prints line number and "message" then exits
# die $LINENO "message"
function die {
    local exitcode=$?
    local line=$1; shift
    if [ $exitcode == 0 ]; then
        exitcode=1
    fi
    err $line "$*"
    # Give buffers a second to flush
    sleep 1
    exit $exitcode
}

# Prints line number and "message" in error format
# err $LINENO "message"
function err {
    local exitcode=$?
    # 2 because 0 is func "err" and 1 is func "die"
    local msg="ERROR ${BASH_SOURCE[2]}:$1 $2"
    echo $msg 1>&2;
    return $exitcode
}

# Test if the named environment variable is set and not zero length
# is_set env-var
is_set() {
    local var=\$"$1"
    eval "[ -n \"$var\" ]" # For ex.: sh -c "[ -n \"$var\" ]" would be better, but several exercises depends on this
}

# date for use in filenames
safe_date() {
    date +%Y_%m_%d__%H_%M_%S_%N
}

git_cmd() {
    local repo_path=$1
    shift
    # this doesn't work with stash so do the other way: cd in a subshell
    #git --git-dir $SCHLEP_WORK_DIR/.git --work-tree $SCHLEP_WORK_DIR "$@"
    (cd "$repo_path" && git "$@")
}

_log_level_error=1
_log_level_warning=2
_log_level_info=3
_log_level_debug=4
_log_level_trace=5
LOG_VERBOSITY=${LOG_VERBOSITY:-$_log_level_info}


log_error() { _log $_log_level_error ERROR "$@"; }
log_warning() { _log $_log_level_warning WARNING "$@"; }
log_info() { _log $_log_level_info INFO "$@"; }
log_debug() { _log $_log_level_debug DEBUG "$@"; }
log_is_trace_enabled() {
    _is_log_level_enabled $_log_level_trace
    local exit_code=$?
    return $exit_code
}
_is_log_level_enabled() {
    local level=${1?"level is required"}
    test $LOG_VERBOSITY -ge $level
    local exit_code=$?
    return $exit_code
}
_log() {
    local level=${1?"level is required"}
    if [ $LOG_VERBOSITY -ge $level ]; then
        echo "${@:2}"
    fi
}

log_var() {
    local var=${1?"var is required"}
    log_debug "${var}=${!var}"
}

schlep_ssh="${GIT_SSH_COMMAND:-ssh}"

run() {
    local user_and_host="${1-}"
    local cmd="${2?cmd is required}"
    if [[ $user_and_host ]]; then
        do_in_ssh $user_and_host "$cmd"
    else
        echo "$cmd" | bash
    fi
}

do_in_ssh() {
    local user_and_host="${1?user_and_host is required}"
    local cmd="${2?cmd is required}"
    # let Bash split $schlep_ssh
    IFS_OLD=$IFS
    IFS=' '
    $schlep_ssh $user_and_host "$cmd"
    IFS=$IFS_OLD
}

copy() {
    src="${1?src is required}"
    dest="${2?dest is required}"
    if [[ $dest =~ ^:.*$ ]]; then
        cp $src ${dest:1}
    else
        rsync -p -e "$schlep_ssh" $src $dest
    fi
}

sanity_check() {
    if [[ -d ./git ]]; then
        die $LINENO "current directory is not a git repository"
    fi
}