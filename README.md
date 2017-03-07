# Schlep

## Why

You need to deploy something. You could `rsync`. But you already have `git`. Git can:

* Copy files (and respect ignored files). In other words, a [push](https://git-scm.com/docs/git-push).
* Do something on the receiving end in response to the push. In other words, a 
`push-to-checkout` [hook](https://git-scm.com/docs/githooks).
* Create built-in save points. In other words, commits.
    * You broke something? Check the [log](https://git-scm.com/docs/git-log).
    * You always amend the last commit? Check the [reflog](https://git-scm.com/docs/git-reflog).

tl;dr schlep is a way of copying changes intelligently and doing whatever is necessary on the destination to get your changes where and how you ultimately want them.

## How

schlep does the following for you:

1. Creates a remote (or local) non-bare git repo with a `push-to-checkout` hook and any subhooks. The main hook (on pushes) does the following:
	1. Stashes any uncommitted changes (in case you were hacking around).
	2. Updates the currently checked out branch (always `master`). (Untracked files are left in place.)
	3. Runs any "subhooks" in `.git/hooks/push.d`. Subhooks are numbered scripts that can do anything you want (e.g. restart affected services). You never edit the main `push-to-checkout` hook.
2. Adds a git "remote" that points to the non-bare git repo with the hook.

## Installation

```bash
$ git clone https://github.com/mlowery/schlep.git
$ cd schlep
$ alias schlep="$(pwd)/schlep"  # persist to all logins with: echo alias schlep=\"$(pwd)/schlep\" >> ~/.bashrc
```

## Quick Start

The below example shows: Creating a local git repo. Adding a file to it. Using schlep to configure the remote receiving git repo. Pushing the change.

```bash
$ cd ~
$ git init repo1
Initialized empty Git repository in /Users/user1/repo1/.git/
$ cd repo1
$ touch master-file
$ git add -A
$ git commit -m initial
[master (root-commit) 6f22998] initial
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 master-file
$ schlep user1@host1:/home/user1/repo1
INFO creating git repo [/home/user1/repo1] and adding master push-to-checkout hook
Initialized empty Git repository in /home/user1/repo1/.git/
INFO adding remote named [test]
$ git push test
Counting objects: 3, done.
Writing objects: 100% (3/3), 212 bytes | 0 bytes/s, done.
Total 3 (delta 0), reused 0 (delta 0)
INFO updating from none to 6f22998cb0a2bf6b128dcac5fb945c41d5b22a8c
To user1@host1:/home/user1/repo1
 * [new branch]      HEAD -> master
$ ssh user1@host1 "ls -la /home/user1/repo1/master-file"
-rw-rw-r-- 1 user1 user1 0 Apr 24 18:53 /home/user1/repo1/master-file
```

## Prerequisites

### Bash and Other Utilities

bash, awk, grep.

### git version 2.4+

Using the appropriate git version is very important--as the features on which schlep relies didn't exist until git version 2.4. Below are some instructions on getting git installed.

#### OS X

* Native installer: https://git-scm.com/download/mac
* MacPorts:

    ```bash
    $ sudo port install git
    ```
* Homebrew: (not tested)

    ```bash
    $ brew install git
    ```

#### Ubuntu

Tested on 14.04 (trusty).

```bash
$ sudo add-apt-repository -y ppa:git-core/ppa
$ sudo apt-get -y update
$ sudo apt-get -y install git
```

### SSH Access and Permissions

If creating a remote git repo (which is the more common scenario), you'll need password-less (certificate-based) SSH access as well as write permission for the git repo.

## Limitations

schlep is only meant as a deployment mechanism. It is not meant as a backup--it doesn't even preserve branches (all branches are force-pushed to `master` on the receiving end). Furthermore, it is only appropriate for a single user (since branches are clobbered).

## Writing Subhooks

subhooks can be written in any language as long as they are executable. However, subhooks that end in `.source.sh` will be sourced rather than executed meaning that any exported variables (e.g. `export x=1`) will be available for later subhooks to consume. This can keep your subhooks generic by simply consuming variables defined earlier that control the generic subhook's behavior. Finally, subhooks receive the same arguments that git passes to the master `push-to-checkout` hook (the new revision). Consult the git documentation for the meaning of this value. Finally, the current working directory while the subhook is running is the git repo work tree (i.e. where git repo branch contents are).

## Usage Examples

In the examples below, assume a user named `user1`, a host named `host1`, and a repo named `repo1`.

### Simple Deploy

Just copy the changes.

```bash
# one time setup
$ schlep user1@host1:/home/user/repo1
# run this each time you want to push changes
$ git push test
```
### Deploy and Restart

Copy and restart. Assumes an Upstart-based service (`/etc/init/repo1`).

```bash
$ cat << EOF > /tmp/50-restart.sh
sudo restart repo1
EOF
# one time setup
$ schlep user1@host1:/home/user/repo1 --file /tmp/50-restart.sh
# run this each time you want to push changes
$ git push test
```

### Deploy and Copy Again

Copy and copy again. This could be used if you need to copy to the ultimate destination using `sudo`.

```bash
$ cat << EOF > /tmp/50-copy.sh
sudo rsync -avhW --no-compress . /some/place/where/repo1/files/should/go
EOF
# one time setup
$ schlep user1@host1:/home/user/repo1 --file /tmp/50-copy.sh
# run this each time you want to push changes
$ git push test
```

### Adding an Additional Subhook Later

schlep can safely be run multiple times with additional arguments. Be aware though that subhooks are never removed.

```bash
$ cat << EOF > /tmp/50-something.sh
echo "hello from $0"
EOF
# one time setup
$ schlep user1@host1:/home/user/repo1 --file /tmp/50-something.sh
$ cat << EOF > /tmp/50-something-else.sh
echo "hello from $0"
EOF
$ schlep user1@host1:/home/user/repo1 --file /tmp/50-something.sh --file /tmp/50-something-else.sh
# run this each time you want to push changes
$ git push test
```

### Forcing a Hook to Run

git won't run hooks if the commit is already present on the receiving end. So you can amend the last commit (i.e. change HEAD to a new commit) and push that.

```bash
$ git commit --amend --no-edit
$ git push test
```

## Troubleshooting

If the default branch isn't `master`, you'll need to check that branch out on the target as schlep only pushes to the `master` branch.

## References

* [Git 2.4 — atomic pushes, push to deploy, and more](https://github.com/blog/1994-git-2-4-atomic-pushes-push-to-deploy-and-more)
* [A Better Way to Git Push to Deploy (updateInstead & push-to-checkout)](http://blog.tfnico.com/2015/05/a-better-way-to-git-push-to-deploy.html)

