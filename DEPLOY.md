# Deployment instructions for PyPi

This file is meant for maintainers of pycapnp, and documents the process for uploading to PyPI.

## Pre-requisites

```
pip install pypandoc cython
```

## Run tests

I typically sanity check by running the tests once again locally, but as long as Travis is green, you're probably fine.

## Add a commit that bumps the version

Bump the version in setup.py, and add descriptions of all the changes to CHANGELOG.md (see 19e1b189caa786c7f572e679d6bb94aadfbdb5e0 for an example commit).

## Run the build and upload

Run the following command to clean up old artifacts, run the build, and then upload the result to PyPI

```
rm -rf bundled/ capnp/version.py capnp/lib/capnp.{h,cpp} build; python setup.py build && python setup.py sdist upload -r PyPI
```

## Test the PyPI release

I manually test the PyPI release after it's been uploaded. I have a few virtualenvs that I manually run the following command in (run this from the pycapnp directory since it runs the tests at the end):
```
yes | pip uninstall pycapnp; pip install pycapnp && py.test test
```

I usually test the following configurations:
- Python 2.7 with and without cython installed
- Python 3.6 with and without cython installed

This step could probably benefit greatly from some automation. Perhaps even Travis could handle it, but I'm not sure how best to trigger Travis from a PyPI release.
