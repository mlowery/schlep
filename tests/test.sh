#!/usr/bin/env bash

# function makes the test invocations read better
schlep() {
    $my_dir/../schlep "${@}"
}

set -euo pipefail
IFS=$'\n\t'

my_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

die() {
    if [[ -d $test_dir ]]; then
        rm -rf "$test_dir"
    fi
    echo "FAILED at line $1"
    exit 1
}

trap 'die ${LINENO}' ERR

test_dir=$(mktemp -d)

echo "test_dir=$test_dir"

start_repo_dir="$test_dir/start_repo"

# create sample repo with branches
mkdir -p "$start_repo_dir"

cd "$start_repo_dir"

git init

touch master-file

git add -A
git commit -m "master commit"

git checkout -b branch1 master

touch branch1-file

git add -A
git commit -m "branch1 commit"

git checkout -b branch2 master

touch branch2-file

git add -A
git commit -m "branch2 commit"

git checkout master

git branch -v

master_hash=$(git rev-parse master)
branch1_hash=$(git rev-parse branch1)
branch2_hash=$(git rev-parse branch2)

# ********** schlep cli **********

schlep -h | grep USAGE

schlep --help | grep USAGE

if ! schlep --not-correct; then
    true  # passed
fi

# ********** schlep, branches **********

schlep $test_dir/repos/schlep_default --file $my_dir/../schlep-files/20-test-subhook.sh --file $my_dir/../schlep-files/21-test-subhook.sh 

[[ -x $test_dir/repos/schlep_default/.git/hooks/push.d/20-test-subhook.sh ]]
[[ -x $test_dir/repos/schlep_default/.git/hooks/push.d/21-test-subhook.sh ]]

git push test

clone_master=$(cd "$test_dir/repos/schlep_default" && git rev-parse HEAD)

[[ $clone_master == $master_hash ]]

[[ -f $test_dir/repos/schlep_default/master-file ]]

git checkout branch1
git push test

[[ -f $test_dir/repos/schlep_default/branch1-file ]]

# ********** schlep, stashing **********

touch "$test_dir/repos/schlep_default/file1"  # makes stash do some work
ls "$test_dir/repos/schlep_default/branch1-file"
echo hello > "$test_dir/repos/schlep_default/branch1-file"  # makes stash do some work
git checkout branch2
git push test
ls "$test_dir/repos/schlep_default/file1"  # confirm still there
[[ ! -f "$test_dir/repos/schlep_defaultr/branch1-file" ]]  # confirm branch1-file not there
[[ -f "$test_dir/repos/schlep_default/branch2-file" ]]  # confirm branch2-file is there

trap - ERR
echo "OK"
echo "If the above line is OK, then this thing passed!"