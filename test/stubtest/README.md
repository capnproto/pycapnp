# Stub tests

Run the complete stub validation from the **pycapnp repository root** (the
directory containing `tox.ini`):

```bash
cd /path/to/pycapnp
python -m tox -e stubtest
```

Install tox first if it is not already available:

```bash
python -m pip install tox
```

The environment runs the runtime-surface tests, `mypy.stubtest`, and
`basedpyright --verifytypes`.
