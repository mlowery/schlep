#!/usr/bin/env bash

###############################################################################
# Clone and/or fetch from bare repo into working dir
#
# Dependencies:
# * WORK_DIR: path to working dir
###############################################################################

set -e

my_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$my_dir/../schlep-lib.sh"

if [[ $SCHLEP_HOOK_DEBUG == 1 ]]; then
    LOG_VERBOSITY=$_log_level_debug
    set -x
fi

oldrev=$1
newrev=$2
refname=$3

is_set WORK_DIR || die $LINENO "WORK_DIR is required"

bare_repo=$(cd "$my_dir/../.." && pwd)

if [[ ! -d $WORK_DIR ]]; then
    log_debug "Cloning into $WORK_DIR"
    mkdir -p $WORK_DIR
    git clone "$bare_repo" $WORK_DIR
fi

# sanity check
[[ -d $WORK_DIR/.git ]] || die $LINENO "$WORK_DIR exists and does not appear to be a git work tree"

# sanity check: make sure origin on existing $WORK_DIR points to this bare repo
if ! git_cmd "$WORK_DIR" remote -v | grep -e "origin\s\+$bare_repo/\?\s\+(fetch)" &> /dev/null; then
    die $LINENO "$WORK_DIR already has an origin that is not $bare_repo"
fi

# sanity check when user doesn't use `init --start-repo` and tries to do run-hook
if ! git show-ref --quiet; then
die $LINENO "There are no refs in $bare_repo. You cannot run \"run-hook\" without any refs. Specify \"--start-repo\" during \"init\" to get some refs."
fi

# guard against stashing and tagging in repo with no commits
if git_cmd "$WORK_DIR" rev-parse HEAD &> /dev/null; then

    # quiet exits with 1 if there were differences and 0 means no differences
    if ! git_cmd "$WORK_DIR" diff --quiet; then
        log_info "Stashing changes..."
        git_cmd "$WORK_DIR" stash save "schlep-$(safe_date)"
    fi

    log_info "Tagging current commit..."
    git_cmd "$WORK_DIR" tag "schlep-$(safe_date)"

fi

log_info "Fetching latest..."
git_cmd "$WORK_DIR" fetch
git_cmd "$WORK_DIR" branch -v
git_cmd "$WORK_DIR" reset --hard origin/${refname#refs/*/}

