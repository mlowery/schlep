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

There are actually three git repos involved. One is on your laptop and that's 
where you commit and push from. One is a remote bare repo (i.e. has no work tree) 
which receives the push (this is where the hook is installed). And finally, the 
last repo is a clone of the bare repo 
(typically colocated with the bare repo) that serves either as a staging directory for your 
deployment process or is the final destination for your code.

The above is the high-level setup. Now let's talk about post-receive hooks. 
After the push is received, git calls an executable named `post-receive` in the 
bare repo. schlep handles this file for you but allows you to drop in "subhooks" 
to do stuff specific to your environment (e.g. restart a service after the new 
code is installed). To accomplish this, schelp controls the `post-receive` but 
creates a directory called `post-receive.d` which is where subhooks are copied. 
Each subhook has the prefix `dd-` where d is a number. This allows the subhooks 
to be ordered.

If you choose, schlep can install an included subhook which clones or fetches 
into a working directory after a push. This is typically a first step to doing 
something with the files so you typically want this subhook. This included 
subhook has a prefix of `15-`. So if you wanted to restart a service after the 
clone/fetch, you would `add-subhook` and specify a number higher than `15`.

subhooks can be written in anything as long as they are runnable. However, 
subhooks that end in `.source.sh` will be sourced rather than executed meaning 
that any exported variables (e.g. `export x=1`) will be available for 
later subhooks to consume. This can keep your subhooks generic by simply consuming 
variables that control the generic subhook's behavior. Finally, subhooks receive 
the same arguments that git passes to the master `post-receive` hook: 
`old-value`, `new-value`, `ref-name`. Consult the git documentation for the meaning of 
these values. However, whereas git passes these in via stdin, 
subhooks receive these as command line arguments.

## Requirements

schlep uses Python 2.7 **only** for the command line interface (i.e. hook setup). During 
`post-receive`, it's all Bash. For the Python part, it only needs the standard 
library.

## Installation (on Ubuntu 14.04)

```bash
$ sudo apt-get -y -q install git-core python-dev python-pip
$ git clone https://github.com/mlowery/schlep.git
$ cd schlep
$ sudo python setup.py install
```

## Usage

Let's look at an example setup. You have a VM that will serve as a test 
environment for a service that you are developing. And you have installed 
schlep on that VM. The service is called foo. You will make changes to the 
service code on your laptop. Commit. And push to the VM. For every push, you 
want the latest code copied and the service restarted.
 

```bash
# export a common arg (or specify it every time with --bare-repo-home)
$ export SCHLEP_BARE_REPO_HOME=/home/bar/repos
# initialize a project called foo; when someone pushes, that commit is checked out in work-dir
$ schlep init foo --start-repo https://github.com/mlowery/foo.git --work-dir ~/foo
# copy in a new sub-hook to restart the service
$ schlep add-subhook foo restart-foo.sh --as-file 50-restart-foo.sh
# optionally, run the entire post-receive hook (for example to start the service because no one has pushed yet)
$ schlep run-hook foo --debug
```

Now the service is running and stable. So make some code changes and commit 
locally. Before you can push, you need to configure a git remote. schlep can help 
with the configuration of the remote (see `make-remote-command`) or you can 
configure it without schlep.

With schlep generating the commands for you:

```bash
$ schlep make-remote-command foo test
# now take this output and run them on your laptop in your git working directory
```

Or you can use this formula:

```bash
$ git remote add <remote-name> <user>@<host>:<bare-repo-home>/<project>.git
# optional: always push everything to same remote branch
$ git config --local remote.<remote-name>.push +HEAD:refs/heads/master
```

So in our example, assuming I'm user `bar` and the VM is called `foo-deploy-vm`:

```bash
$ git remote add foo-deploy bar@foo-deploy-vm:/home/bar/foo.git
$ git config --local remote.foo-deploy.push +HEAD:refs/heads/master
```

Then to push the code and restart the service:

```bash
$ git push foo-deploy
```

