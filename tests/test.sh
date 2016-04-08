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

git checkout -b branch1 master

touch branch1

git add -A
git commit -m "branch1 commit"

git checkout -b branch2 master

touch branch2

git add -A
git commit -m "branch2 commit"

# affects clone --bare
git checkout master

git branch -v

master_hash=$(git rev-parse master)
branch1_hash=$(git rev-parse branch1)
branch2_hash=$(git rev-parse branch2)

# schlep init

schlep -h | grep usage

schlep --help | grep usage

export SCHLEP_BARE_REPO_HOME="$test_dir"

schlep init schlep_default

[[ -x $test_dir/schlep_default.git/hooks/post-receive ]]
[[ -d $test_dir/schlep_default.git/hooks/post-receive.d ]]

schlep init schlep_start --start-repo "$start_repo_dir"

git clone "$test_dir/schlep_start.git" "$test_dir/schlep_start_clone"

clone_master=$(cd "$test_dir/schlep_start_clone" && git rev-parse HEAD)

[[ $clone_master == $master_hash ]]

schlep init schlep_with_work_dir --start-repo "$start_repo_dir" --work-dir "$test_dir/work_schlep_with_work_dir"



# schlep add-subhook

bad_subhook="$test_dir/bad_subhook"
echo '#!/usr/bin/env bash
set -x
exit 1
' > $bad_subhook

schlep init schlep_with_bad_subhook
schlep add-subhook schlep_with_bad_subhook $bad_subhook --as-file 50-bad-subhook.sh

# schlep run-hook

schlep init schlep_with_work_dir_no_start_repo_dir --work-dir "$test_dir/work_schlep_with_work_dir_no_start_repo_dir"
if ! schlep run-hook schlep_with_work_dir_no_start_repo_dir; then
    # passed
    true
fi

schlep run-hook schlep_with_work_dir --debug
clone_master=$(cd "$test_dir/work_schlep_with_work_dir" && git rev-parse HEAD)

[[ $clone_master == $master_hash ]]

schlep run-hook schlep_with_work_dir --ref refs/heads/branch1 --debug
clone_branch1=$(cd "$test_dir/work_schlep_with_work_dir" && git rev-parse HEAD)

[[ $clone_branch1 == $branch1_hash ]]

touch "$test_dir/work_schlep_with_work_dir/file1"  # makes stash do some work
ls "$test_dir/work_schlep_with_work_dir/initial"
echo hello > "$test_dir/work_schlep_with_work_dir/initial"  # makes stash do some work
schlep run-hook schlep_with_work_dir --debug
ls "$test_dir/work_schlep_with_work_dir/file1"  # confirm still there


if ! schlep run-hook schlep_with_bad_subhook --debug; then
    # passed
    true
fi

schlep make-remote-command schlep_start test

trap - ERR
echo "OK"
echo "If the above line is OK, then this thing passed!"