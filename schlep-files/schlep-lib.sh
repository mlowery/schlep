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

# date for use in filenames
safe_date() {
    date +%Y_%m_%d__%H_%M_%S_%N
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
    if is_local "$dest"; then
        cp "$src" "$dest"
    else
        rsync -p -e "$schlep_ssh" "$src" "$dest"
    fi
}

is_local() {
    local git_repo_dir="${1?git_repo_dir is required}"
    # if it contains a colon, then it's remote
    [[ ! $git_repo_dir =~ : ]]
}

sanity_check() {
    local user_and_host="${1-}"
    if [[ -d ./git ]]; then
        die $LINENO "current directory is not a git repository"
    fi
    local ver_string
    if [[ $user_and_host ]]; then
        # awk runs on the entire ssh response
        ver_string=$(do_in_ssh $user_and_host "git --version" | awk '/git version / {print $3}')
    else
        # match `git version` since hub tool might be present
        ver_string=$(git --version | awk '/git version / {print $3}')
    fi
    check_git_version "$ver_string"
}

check_git_version() {
    local ver_string="${1?ver_string is required}"
    local err_msg="schlep requires git version 2.4 or later"
    IFS_OLD=$IFS
    IFS=' '
    # http://stackoverflow.com/a/5257398
    local ver_array=(${ver_string//./ })
    
    local major=${ver_array[0]}
    local minor=${ver_array[1]}
    IFS=$IFS_OLD
    if (( $major < 2 )); then
        die $LINENO $err_msg
    fi
    if (( $major > 2 )); then
        return 0
    fi
    if (( $minor < 4 )); then
        die $LINENO $err_msg
    fi
    return 0
}
