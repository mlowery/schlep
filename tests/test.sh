#!/usr/bin/env bash

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

# affects clone --bare
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

# ********** schlep no work dir **********

schlep $test_dir/repos/schlep_default.git

git push test

clone_master=$(cd "$test_dir/repos/schlep_default.git" && git rev-parse HEAD)

[[ $clone_master == $master_hash ]]

git remote rm test

# ********** schlep with work dir **********

schlep $test_dir/repos/schlep_with_work_dir.git -w "$test_dir/work/schlep_with_work_dir"

git push test

[[ -f $test_dir/work/schlep_with_work_dir/master-file ]]

git checkout branch1
git push test

[[ -f $test_dir/work/schlep_with_work_dir/branch1-file ]]

# ********** stash **********

touch "$test_dir/work/schlep_with_work_dir/file1"  # makes stash do some work
ls "$test_dir/work/schlep_with_work_dir/branch1-file"
echo hello > "$test_dir/work/schlep_with_work_dir/branch1-file"  # makes stash do some work
git checkout branch2
git push test
ls "$test_dir/work/schlep_with_work_dir/file1"  # confirm still there
[[ ! -f "$test_dir/work/schlep_with_work_dir/branch1-file" ]]
[[ -f "$test_dir/work/schlep_with_work_dir/branch2-file" ]]

trap - ERR
echo "OK"
echo "If the above line is OK, then this thing passed!"