#!/usr/bin/env bash

###############################################################################
# Clone and/or fetch from bare repo into working dir
#
# Dependencies:
# * SCHLEP_WORK_DIR: path to working dir
###############################################################################

set -euo pipefail
IFS=$'\n\t'

my_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$my_dir/../schlep-lib.sh"

oldrev=$1
newrev=$2
refname=$3

is_set SCHLEP_WORK_DIR || die $LINENO "SCHLEP_WORK_DIR is required"

bare_repo=$(cd "$my_dir/../.." && pwd)

if [[ ! -d $SCHLEP_WORK_DIR ]]; then
    log_debug "Cloning into $SCHLEP_WORK_DIR"
    mkdir -p $SCHLEP_WORK_DIR
    git clone "$bare_repo" $SCHLEP_WORK_DIR
fi

# sanity check
[[ -d $SCHLEP_WORK_DIR/.git ]] || die $LINENO "$SCHLEP_WORK_DIR exists and does not appear to be a git work tree"

# sanity check: make sure origin on existing $SCHLEP_WORK_DIR points to this bare repo
if ! git_cmd "$SCHLEP_WORK_DIR" remote -v | grep -e "origin\s\+$bare_repo/\?\s\+(fetch)" &> /dev/null; then
    die $LINENO "$SCHLEP_WORK_DIR already has an origin that is not $bare_repo"
fi

# sanity check when user doesn't use `init --start-repo` and tries to do run-hook
if ! git_cmd "$SCHLEP_WORK_DIR" show-ref --quiet; then
die $LINENO "There are no refs in $bare_repo. You cannot run \"run-hook\" without any refs. Specify \"--start-repo\" during \"init\" to get some refs."
fi

# guard against stashing and tagging in repo with no commits
if git_cmd "$SCHLEP_WORK_DIR" rev-parse HEAD &> /dev/null; then

    # quiet exits with 1 if there were differences and 0 means no differences
    if ! git_cmd "$SCHLEP_WORK_DIR" diff --quiet; then
        log_info "Stashing changes..."
        git_cmd "$SCHLEP_WORK_DIR" stash save "schlep-$(safe_date)"
    fi

    log_info "Tagging current commit..."
    git_cmd "$SCHLEP_WORK_DIR" tag "schlep-$(safe_date)"

fi

log_info "Fetching latest..."
git_cmd "$SCHLEP_WORK_DIR" fetch
git_cmd "$SCHLEP_WORK_DIR" branch -v
git_cmd "$SCHLEP_WORK_DIR" reset --hard origin/${refname#refs/*/}

