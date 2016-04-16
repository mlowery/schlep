# Schlep

## Why

You need to deploy something. You could rsync. But you already have git. Git can:

* Copy files (and respect ignored files). In other words, a [push](https://git-scm.com/docs/git-push).
* Do something on the receiving end in response to the push. In other words, a 
`post-receive` [hook](https://git-scm.com/docs/githooks).
* Create built-in save points. In other words, commits.
    * You broke something? Check the [log](https://git-scm.com/docs/git-log).
    * You always amend the last commit? Check the [reflog](https://git-scm.com/docs/git-reflog).

## How

There are actually three git repos involved:
1. a repo where you commit to and push from (e.g. your laptop)
2. a "bare" repo (i.e. has no work tree) which receives the push (this is where the hook is installed)
3. a clone of the bare repo (typically co-located with the bare repo) that serves either as a staging directory for your 
deployment process or is the final destination for your code

The above is the high-level setup. Now let's talk about post-receive hooks. 
After the push is received, git calls an executable named `post-receive` in the 
bare repo. schlep handles this file for you but allows you to drop in "subhooks" 
to do stuff specific to your environment (e.g. restart a service after the new 
code is installed). To accomplish this, schelp controls the master `post-receive` hook but 
creates a directory called `post-receive.d` which is where subhooks are copied. 
Each subhook has the prefix `dd-` where `d` is a number. This allows the subhooks 
to be ordered however you like.

If you choose, schlep can install an included subhook which clones or fetches 
into a working directory after a push. This is typically a first step to doing 
something useful with the files so you typically want this subhook. This included 
subhook has a prefix of `15-`. So if you wanted to restart a service after the 
clone/fetch, you would add a subhook with a prefix higher than `15`.

subhooks can be written in anything as long as they are runnable. However, 
subhooks that end in `.source.sh` will be sourced rather than executed meaning 
that any exported variables (e.g. `export x=1`) will be available for 
later subhooks to consume. This can keep your subhooks generic by simply consuming 
variables defined earlier that control the generic subhook's behavior. Finally, subhooks receive 
the same arguments that git passes to the master `post-receive` hook: 
`old-value`, `new-value`, `ref-name`. Consult the git documentation for the meaning of 
these values. However, whereas git passes these in via stdin, 
subhooks receive these as command line arguments.

## Requirements

schlep is 100% pure Bash. Tested on Bash 4.x.

## Installation

```bash
$ git clone https://github.com/mlowery/schlep.git
$ alias schlep="$pwd/schlep/schlep"  # add to ~/.bashrc
```

## Usage

Let's look at an example setup. You have a VM that will serve as a test 
environment for a service that you are developing. The service is called `foo`. You will make changes to the 
service code on your laptop. Commit. And push to the VM. For every push, you 
want the latest code copied and the service restarted. In this example, assume a user called `bar` and the VM called `foo-deploy-vm`:


One-time setup:

Assume that the content of `50-deploy-foo.sh` is:

```bash
#!/usr/bin/env bash

# if $SCHLEP_WORK_DIR is already where the code should live, then just restart your sevrvice
sudo rsync -avhW --no-compress $SCHLEP_WORK_DIR/foo /some/place/where/foo/lives

sudo restart foo
```

```bash
$ cd project-foo  # a git working directory
# initialize a project called foo; when someone pushes, that commit is checked out in work-dir
$ schlep /home/bar/repos/foo.git -s bar@foo-deploy-vm --work-dir /home/bar/foo --file 50-deploy-foo.sh
```

Every time to push latest code:
```bash
$ git push test
```

