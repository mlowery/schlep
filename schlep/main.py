# -*- coding: utf-8 -*-

from __future__ import absolute_import

# TODO what about a .schlep dir within each project that contains hooks that are run during a push?


import argparse
import getpass
import logging
import os
import shutil
import stat
import socket
import subprocess
import sys
import shlex

debug = False

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
consoleHandler = logging.StreamHandler()
consoleHandler.setFormatter(logging.Formatter('%(levelname)s %(message)s'))
logger.addHandler(consoleHandler)

ENV_SCHLEP_HOOK_DEBUG = 'SCHLEP_HOOK_DEBUG'
ENV_SCHLEP_BARE_REPO_HOME = 'SCHLEP_BARE_REPO_HOME'
DEFAULT_SUBHOOK_FILE = '15-fetch.sh'
DEFAULT_SUBHOOK_VAR_FILE = '10-work-dir.source.sh'
DEFAULT_REF = 'refs/heads/master'
FILES_DIR = os.path.join(os.path.split(__file__)[0], "files")


### RunResponse, RunError, expand_args(), run() all copied from https://github.com/kennethreitz/envoy

class RunError(Exception):
    def __init__(self, response):
        self.response = response

    def _format(self, s):
        return '%s\n%s\n%s' % ('*' * 80, s, '*' * 80)

    def __str__(self):
        s = "Command '%s' returned %d" % (self.response.command,
                                          self.response.status_code)
        if self.response.std_out:
            s += '\n\nstdout:\n%s' % self._format(self.response.std_out)
        if self.response.std_err:
            s += '\n\nstderr:\n%s' % self._format(self.response.std_err)
        return s


class RunResponse(object):

    def __init__(self, command, status_code, std_out, std_err):
        super(RunResponse, self).__init__()

        self.command = command
        self.std_out = std_out
        self.std_err = std_err
        self.status_code = status_code


def expand_args(command):
    """Parses command strings and returns a Popen-ready list."""
    if isinstance(command, str):
        splitter = shlex.shlex(command)
        splitter.whitespace_split = True
        command = []
        while True:
            token = splitter.get_token()
            if token:
                command.append(token)
            else:
                break
    return command

def run(command, data=None, env=None, cwd=None, expected_status_codes=[0],
        strip=True, capture=False, sudo=False, shell=False):
    environ = dict(os.environ)
    environ.update(env or {})
    if sudo:
        command = 'sudo %s' % command
    logger.debug('%s$ %s', cwd or os.getcwd(), command)
    if shell:
        # for shell=True, just hand the entire string as is; do not tokenize
        command_arg = command
    else:
        command_arg = expand_args(command)
    process = subprocess.Popen(command_arg,
                               universal_newlines=True,
                               shell=shell,
                               env=environ,
                               stdin=subprocess.PIPE if data else None,
                               stdout=subprocess.PIPE if capture else None,
                               stderr=subprocess.PIPE if capture else None,
                               cwd=cwd,
                              )
    std_out, std_err = process.communicate(data)
    if capture and strip:
        std_out = std_out.rstrip('\n')
    response = RunResponse(command, process.returncode, std_out, std_err)
    if response.status_code not in expected_status_codes:
        raise RunError(response)
    return response


def fatal(msg=None):
    e = sys.exc_info()[1]
    if e:
        logger.exception('an error occurred')
        if isinstance(e, subprocess.CalledProcessError):
            logger.debug('Output: %s' % e.output)
    elif msg:
        print('ERROR %s' % msg)
    sys.exit(1)


def chmod_ax(path):
    st = os.stat(path)
    os.chmod(path, st.st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def _make_bare_repo_path(bare_repo_home, project, check_exists=True):
    bare_repo_path = os.path.join(bare_repo_home, '%s.git' % project)
    if not os.path.isdir(bare_repo_path):
        fatal('project %s does not exist' % project)
    return bare_repo_path

def cmd_init(args):
    _cmd_init(args.bare_repo_home, args.project, args.start_repo,
              args.start_branch, args.work_dir)


def _cmd_init(bare_repo_home, project, start_repo, start_branch, work_dir):
    bare_repo_path = os.path.join(bare_repo_home, '%s.git' % project)
    if not os.path.isdir(bare_repo_path):
        logger.debug('%s does not exist; creating' % bare_repo_path)
        os.makedirs(bare_repo_path)
    else:
        fatal('%s already exists' % bare_repo_path)
    if start_repo:
        run('git clone --bare %s %s' % (start_repo, bare_repo_path))
    else:
        logger.debug('no --start-repo; init\'ing empty bare repo')
        run('git init --bare', cwd=bare_repo_path)

    logger.info('created bare repo: %s' % bare_repo_path)

    hooks_dir = os.path.join(bare_repo_path, 'hooks')
    # copy post-receive
    shutil.copy(os.path.join(FILES_DIR, 'post-receive'), hooks_dir)
    chmod_ax(os.path.join(hooks_dir, 'post-receive'))
    # copy schlep-lib.sh
    shutil.copy(os.path.join(FILES_DIR, 'schlep-lib.sh'), hooks_dir)

    post_receive_d_dir = os.path.join(hooks_dir, 'post-receive.d')
    # create hooks/post-receive.d
    os.makedirs(post_receive_d_dir)

    if work_dir:
        logger.debug('adding default subhook (clone/fetch from bare repo to work dir)')
        shutil.copy(os.path.join(FILES_DIR, DEFAULT_SUBHOOK_FILE), post_receive_d_dir)
        chmod_ax(os.path.join(post_receive_d_dir, DEFAULT_SUBHOOK_FILE))
        work_dir_script_path = os.path.join(post_receive_d_dir, DEFAULT_SUBHOOK_VAR_FILE)
        with open(work_dir_script_path, 'w') as f:
            f.write("""#!/usr/bin/env bash

export WORK_DIR=%s
""" % work_dir)
        chmod_ax(work_dir_script_path)
        logger.info('installed default subhook (clone/fetch to %s)' % work_dir)


def cmd_add_subhook(args):
    _cmd_add_subhook(args.bare_repo_home, args.project, args.file, args.as_file)


def _cmd_add_subhook(bare_repo_home, project, file, as_file):
    bare_repo_path = _make_bare_repo_path(bare_repo_home, project)
    hooks_dir = os.path.join(bare_repo_path, 'hooks')
    post_receive_d_dir = os.path.join(hooks_dir, 'post-receive.d')
    dest = post_receive_d_dir
    if as_file:
        dest = os.path.join(post_receive_d_dir, as_file)
    else:
        dest = os.path.join(post_receive_d_dir, os.path.basename(file))
    shutil.copy(os.path.join(file), dest)
    chmod_ax(dest)
    logger.info('copied %s to %s' % (file, dest))


def cmd_run_hook(args):
    _cmd_run_hook(args.bare_repo_home, args.project, args.ref, args.hook_debug)


def _cmd_run_hook(bare_repo_home, project, ref, hook_debug):
    bare_repo_path = _make_bare_repo_path(bare_repo_home, project)
    env = os.environ.copy()
    if hook_debug:
        env[ENV_SCHLEP_HOOK_DEBUG] = '1'
    hook = os.path.join(bare_repo_path, 'hooks', 'post-receive')
    logger.info('running %s' % hook)
    try:
        print('*' * 80)
        run(hook, data='1 2 %s\n' % ref, env=env)
        print('*' * 80)
        logger.info('hook returned 0')
    except RunError as e:
        logger.exception('hook returned %s' % e.response.status_code)
        sys.exit(e.response.status_code)


def cmd_make_remote_command(args):
    _cmd_make_remote_command(args.bare_repo_home, args.project, args.remote_name)


def _cmd_make_remote_command(bare_repo_home, project, remote_name):
    bare_repo_path = _make_bare_repo_path(bare_repo_home, project)
    print('git remote add %s %s@%s:%s' % (remote_name,
                                          getpass.getuser(),
                                          socket.getfqdn(),
                                          bare_repo_path))
    print('# optional: always push everything to same remote branch')
    print('git config --local remote.%s.push +HEAD:refs/heads/master' %
          remote_name)


def make_parser():
    parser = argparse.ArgumentParser(
        description='Schlep: Git-based Deployment')
    parser.add_argument('--bare-repo-home',
                        default=os.environ.get(ENV_SCHLEP_BARE_REPO_HOME, ''),
                        help='Directory where all projects will be created. Defaults to env[%s].' % ENV_SCHLEP_BARE_REPO_HOME)
    parser.add_argument('--debug', action='store_true', default=False,
                        help='Print more details.')
    subparsers = parser.add_subparsers()
    parser_init = subparsers.add_parser('init', help='Create bare repo (and optionally install the default subhook).')
    parser_init.set_defaults(func=cmd_init)
    parser_init.add_argument('project',
                             help='Name of project (bare repo name).')
    parser_init.add_argument('--start-repo', help='Bare repo will be initialized with the contents of this repo.')
    parser_init.add_argument('--start-branch', default='master', help='Branch within start-repo to make master branch of bare repo.')
    parser_init.add_argument('--work-dir', help='Add default subhook (which clones or fetches to work dir).')
    parser_add_subhook = subparsers.add_parser('add-subhook', help='Add subhook to main post-receive hook.')
    parser_add_subhook.set_defaults(func=cmd_add_subhook)
    parser_add_subhook.add_argument('project', help='Name of project (bare repo name).')
    parser_add_subhook.add_argument('file', help='File to copy as a subhook.')
    parser_add_subhook.add_argument('--as-file', help='Give file a new name.')
    parser_run_hook = subparsers.add_parser('run-hook', help='Force run of entire post-recieve hook.')
    parser_run_hook.set_defaults(func=cmd_run_hook)
    parser_run_hook.add_argument('project', help='Name of project (bare repo name).')
    parser_run_hook.add_argument('--debug', dest='hook_debug', action='store_true', default=False, help='Run hook with debug flag.')
    parser_run_hook.add_argument('--ref', default=DEFAULT_REF, help='The branch to "push" during the hook run. Defaults to %s.' % DEFAULT_REF)
    parser_make_remote_command = subparsers.add_parser('make-remote-command', help='Generate `git remote add` command.')
    parser_make_remote_command.set_defaults(func=cmd_make_remote_command)
    parser_make_remote_command.add_argument('project', help='Name of project (bare repo name).')
    parser_make_remote_command.add_argument('remote_name', metavar='remote-name', help='Name of the remote (can be anything memorable).')
    return parser


def has_text(name, value):
    if not value:
        fatal('%s is required' % name)

def main():
    try:
        args = make_parser().parse_args()
        global debug
        debug = args.debug
        if debug:
            logger.setLevel(logging.getLevelName('DEBUG'))
        has_text('--bare-repo-home', args.bare_repo_home)

        args.func(args)

    except Exception as e:
        fatal()

if __name__ == '__main__':
    main()
