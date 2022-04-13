import copy
import hashlib
import json
import logging
import subprocess
import sys
from abc import ABC, abstractmethod
from contextlib import contextmanager
from os import path, makedirs, getcwd, chdir, walk, utime
from shlex import quote
from shutil import copy, make_archive, rmtree

logging.basicConfig(format="%(levelname)s: %(message)s", filename='package.log', filemode='w', level=logging.DEBUG)


def create_zip_file(source_dir, target_file):
    """
    Creates a zip file from a directory.
    """
    target_file = path.abspath(target_file)
    target_dir = path.dirname(target_file)
    if not path.exists(target_dir):
        makedirs(target_dir)
    target_base, _ = path.splitext(target_file)
    logging.debug(f"{target_file}, {target_dir}, {target_base}, {source_dir}")
    return make_archive(
        target_base,
        format='zip',
        root_dir=source_dir,
    )


@contextmanager
def tempdir():
    """
    Creates a temporary directory and then deletes it afterwards.
    """

    build_dir = tempfile.tempdir
    try:
        yield build_dir
    finally:
        logging.debug(f"Removing directory: {build_dir}")
        rmtree(build_dir)


@contextmanager
def cd(_path):
    """
    Changes the working directory.
    """

    cwd = getcwd()
    logging.debug(f"Changing directory to {_path}")
    try:
        chdir(_path)
        yield
    finally:
        chdir(cwd)


def format_command(command):
    """
    Formats a command for displaying on screen.
    """

    args = []
    for arg in command:
        if ' ' in arg:
            args.append('"' + arg + '"')
        else:
            args.append(arg)
    return ' '.join(args)


def run(*args, **kwargs):
    """
    Runs a command.
    """
    logging.debug(f"Running: {format_command(args)}")
    sys.stdout.flush()
    try:
        subprocess.run(args, **kwargs)
    except subprocess.CalledProcessError as err:
        logging.error(f'Command failed: {err.stderr}')
        raise err


def normalize_file_timestamps(runtime_dir):
    for dirpath, dirnames, filenames in walk(runtime_dir):
        for filename in filenames:
            filepath = path.join(dirpath, filename)
            utime(filepath, (0, 0))


def create_zip(self, source_path, target_file):
    return make_archive(
        target_file,
        format='zip',
        root_dir=source_path,
    )


class ContentHash:
    def __init__(self, source_paths):
        self.source_paths = source_paths
        self.hash = hashlib.md5()

    def generate(self):
        for source_path in self.source_paths:
            if path.isfile(source_path):
                self.hash.update(open(source_path, "rb").read())
        return self.hash.hexdigest()


class Workflow(ABC):
    def __init__(self, runtime, dependency_lock_file, dependency_file, docker_image=None,
                 pre_package_commands=[]):
        self.runtime = runtime
        self.docker_image = docker_image
        self.pre_package_commands = pre_package_commands
        self.dependency_lock_file = dependency_lock_file
        self.package_dir = path.dirname(self.dependency_lock_file)
        self.dependency_file = path.join(self.package_dir, dependency_file)
        self.build_dir = './builds'
        if docker_image:
            self.docker_image = docker_image
        else:
            self.docker_image = 'lambci/lambda:build-{}'.format(self.runtime)

        if not path.isfile(self.dependency_file):
            logging.error(f"Dependency file not found: {self.dependency_file}")
            exit(1)

    def run(self):
        build_layer_dir = path.join(self.build_dir, 'lambda-layer-deps',
                                    ContentHash([self.dependency_lock_file, __file__]).generate())
        archive_file = f"{build_layer_dir}.zip"
        if path.exists(archive_file):
            logging.info(f"Archive file already exists: {archive_file}, skipping build step")
            return f"{build_layer_dir}.zip"
        logging.debug(f"Creating build layer directory: {build_layer_dir}")
        makedirs(build_layer_dir, exist_ok=True)
        runtime_dir = self.get_runtime_dir(build_layer_dir)
        logging.debug(f"Creating runtime directory: {runtime_dir}")
        makedirs(runtime_dir, exist_ok=True)
        logging.debug(f"Copying dependency lock file {self.dependency_lock_file} to {runtime_dir}")
        copy(self.dependency_lock_file, runtime_dir)
        logging.debug(f"Copying dependency file {self.dependency_file} to {runtime_dir}")
        copy(self.dependency_file, runtime_dir)
        with cd(runtime_dir):
            self.preinstall()
            logging.debug("Installing requirements")
            self.install()
            logging.debug("Normalizing file utime")
            normalize_file_timestamps(runtime_dir)
        logging.debug(f"Creating archive: {archive_file}")
        return make_archive(
            build_layer_dir,
            format='zip',
            root_dir=build_layer_dir,
        )

    @abstractmethod
    def get_runtime_dir(self, build_layer_dir):
        pass

    def preinstall(self):
        pass

    @abstractmethod
    def install(self):
        pass


class PoetryWorkflow(Workflow):
    def __init__(self, runtime, dependency_lock_file, docker_image=None, pre_package_commands=[]):
        super().__init__(runtime, dependency_lock_file, 'pyproject.toml', docker_image, pre_package_commands)

    @property
    def pip_cmd(self):
        return 'pip3' if self.runtime.startswith('python3') else 'pip2'

    def preinstall(self):
        logging.debug(f"Building requirements since poetry does not support targeting a directory")
        return run('poetry export --without-hashes -f requirements.txt -o requirements.txt', shell=True, check=True,
                   capture_output=True)

    def install(self):
        install_cmd = f'cd /var/task && {self.pip_cmd} install --prefix= -r requirements.txt --target .'
        docker_cmd = f'docker run --rm -v "$PWD":/var/task {self.docker_image} /bin/sh -c'
        commands = ' '.join([docker_cmd, quote(' && '.join(self.pre_package_commands + [install_cmd]))])
        return run(commands, shell=True, check=True, capture_output=True)

    def get_runtime_dir(self, build_layer_dir):
        return path.join(build_layer_dir, f"python/lib/{self.runtime}/site-packages/")


class NpmWorkflow(Workflow):
    def __init__(self, runtime, dependency_lock_file, docker_image=None, pre_package_commands=[]):
        super().__init__(runtime, dependency_lock_file, 'package.json', docker_image, pre_package_commands)

    def install(self):
        install_cmd = f'cd /var/task && npm install --production'
        docker_cmd = f'docker run --rm -v "$PWD":/var/task {self.docker_image} /bin/sh -c'
        commands = ' '.join([docker_cmd, quote(' && '.join(self.pre_package_commands + [install_cmd]))])
        return run(commands, shell=True, check=True, capture_output=True)

    def get_runtime_dir(self, build_layer_dir):
        return path.join(build_layer_dir, f"nodejs/")


class YarnWorkflow(Workflow):
    def __init__(self, runtime, dependency_lock_file, docker_image=None, pre_package_commands=[]):
        super().__init__(runtime, dependency_lock_file, 'package.json', docker_image, pre_package_commands)

    def install(self):
        install_cmd = f'cd /var/task && yarn install --production'
        docker_cmd = f'docker run --rm -v "$PWD":/var/task {self.docker_image} /bin/sh -c'
        commands = ' '.join([docker_cmd, quote(' && '.join(self.pre_package_commands + [install_cmd]))])
        return run(commands, shell=True, check=True, capture_output=True)

    def get_runtime_dir(self, build_layer_dir):
        return path.join(build_layer_dir, f"nodejs/")


def main():
    query = json.load(sys.stdin)
    dependency_manager = query['dependency_manager']
    if dependency_manager == 'poetry':
        workflow = PoetryWorkflow
    elif dependency_manager == 'npm':
        workflow = NpmWorkflow
    elif dependency_manager == 'yarn':
        workflow = YarnWorkflow
    else:
        raise Exception(f"Invalid dependency manager: {dependency_manager}")

    archive_file = workflow(
        query["runtime"], query["dependency_lock_file"], query.get("docker_image"),
        json.loads(query.get("pre_package_commands"))).run()

    print(json.dumps({'output_path': archive_file}))


if __name__ == "__main__":
    main()
