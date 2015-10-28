#!/usr/bin/env bash

set -ex

die() {
    if [[ -d $test_dir ]]; then
        rm -rf "$test_dir"
    fi
    echo "FAILED"
    exit 1
}

trap 'die' ERR

test_dir=$(mktemp -d)

echo "test_dir=$test_dir"

start_repo_dir="$test_dir/start_repo"

# create repo with branches (to serve as start-repo)
mkdir -p "$start_repo_dir"

cd "$start_repo_dir"

git init

touch initial

git add -A
git commit -m "initial commit"

export SCHLEP_BARE_REPO_HOME="$test_dir"
schlep init schlep_with_work_dir --start-repo "$start_repo_dir" --work-dir "$test_dir/work_schlep_with_work_dir"


git clone "$start_repo_dir" "$test_dir/clone_reftest"
(cd "$test_dir/clone_reftest" && git remote add test "$test_dir/schlep_with_work_dir.git")
(cd "$test_dir/clone_reftest" && date > initial && git add -A && git commit -m work && git push test)


clone_dir_hash=$(cd "$test_dir/clone_reftest" && git rev-parse HEAD)
work_dir_hash=$(cd "$test_dir/work_schlep_with_work_dir" && git rev-parse HEAD)

sleep 2
(cd "$test_dir/clone_reftest" && date > initial && git add -A && git commit -m work && git push test)

clone_dir_hash=$(cd "$test_dir/clone_reftest" && git rev-parse HEAD)
work_dir_hash=$(cd "$test_dir/work_schlep_with_work_dir" && git rev-parse HEAD)

trap - ERR
echo "OK"
echo "If the above line is OK, then this thing passed!"