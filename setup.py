#!/usr/bin/env python
# -*- coding: utf-8 -*-


try:
    from setuptools import setup
except ImportError:
    from distutils.core import setup


with open('README.md') as readme_file:
    readme = readme_file.read()

requirements = [
    # TODO: put package requirements here
]

setup(
    name='schlep',
    version='0.1.0',
    description="Schlep: Git-based Deployment",
    long_description=readme,
    author="Mat Lowery",
    author_email='mat@matlowery.com',
    url='https://github.com/mlowery/schlep',
    packages=[
        'schlep',
    ],
    package_dir={'schlep':
                 'schlep'},
    package_data={'schlep': ['files/*']},
    install_requires=requirements,
    zip_safe=False,
    keywords='schlep',
    classifiers=[
        'Development Status :: 2 - Pre-Alpha',
        'Intended Audience :: Developers',
        'Natural Language :: English',
        "Programming Language :: Python :: 2",
        'Programming Language :: Python :: 2.7',
    ],
    entry_points={
        'console_scripts': [
            'schlep = schlep.main:main'
        ]
    }
)
