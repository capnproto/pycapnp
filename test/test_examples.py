import os
import pytest
import socket
import subprocess
import sys
import time

examples_dir = os.path.join(os.path.dirname(__file__), "..", "examples")
hostname = "localhost"


processes = []


@pytest.fixture
def cleanup():
    yield
    for p in processes:
        p.kill()


def run_subprocesses(
    address, server, client, wildcard_server=False, ipv4_force=True
):  # noqa
    server_attempt = 0
    server_attempts = 2
    done = False
    addr, port = address.split(":")
    c_address = address
    s_address = address
    while not done:
        assert server_attempt < server_attempts, "Failed {} server attempts".format(
            server_attempts
        )
        server_attempt += 1

        # Force ipv4 for tests (known issues on GitHub Actions with IPv6 for some targets)
        if "unix" not in addr and ipv4_force:
            addr = socket.gethostbyname(addr)
            c_address = "{}:{}".format(addr, port)
            s_address = c_address
            if wildcard_server:
                s_address = "*:{}".format(port)  # Use wildcard address for server
            print("Forcing ipv4 -> {} => {} {}".format(address, c_address, s_address))

        # Start server
        cmd = [sys.executable, os.path.join(examples_dir, server), s_address]
        serverp = subprocess.Popen(cmd, stdout=sys.stdout, stderr=sys.stderr)
        print("Server started (Attempt #{})".format(server_attempt))
        processes.append(serverp)
        retries = 300
        # Loop until we have a socket connection to the server (with timeout)
        while True:
            try:
                if "unix" in address:
                    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                    result = sock.connect_ex(port)
                    if result == 0:
                        break
                else:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    result = sock.connect_ex((addr, int(port)))
                    if result == 0:
                        break
                    sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
                    result = sock.connect_ex((addr, int(port)))
                    if result == 0:
                        break
            except socket.gaierror as err:
                print("gaierror: {}".format(err))
            # Give the server some small amount of time to start listening
            time.sleep(0.1)
            retries -= 1
            if retries == 0:
                serverp.kill()
                print("Timed out waiting for server to start")
                break

            if serverp.poll() is not None:
                print("Server exited prematurely: {}".format(serverp.returncode))
                break

        # 3 tries per server try
        client_attempt = 0
        client_attempts = 3
        while not done:
            if client_attempt >= client_attempts:
                print("Failed {} client attempts".format(client_attempts))
                break
            client_attempt += 1

            # Start client
            cmd = [sys.executable, os.path.join(examples_dir, client), c_address]
            clientp = subprocess.Popen(cmd, stdout=sys.stdout, stderr=sys.stderr)
            print("Client started (Attempt #{})".format(client_attempt))
            processes.append(clientp)

            retries = 30 * 10
            # Loop until the client is finished (with timeout)
            while True:
                if clientp.poll() == 0:
                    done = True
                    break

                if clientp.poll() is not None:
                    print("Client exited prematurely: {}".format(clientp.returncode))
                    break
                time.sleep(0.1)
                retries -= 1
                if retries == 0:
                    print("Timed out waiting for client to finish")
                    clientp.kill()
                    break

        serverp.kill()

    serverp.kill()


def test_async_calculator_example(cleanup):
    address = "{}:36432".format(hostname)
    server = "async_calculator_server.py"
    client = "async_calculator_client.py"
    run_subprocesses(address, server, client)


@pytest.mark.xfail(
    reason="Some versions of python don't like to share ports, don't worry if this fails"
)
def test_thread_example(cleanup):
    address = "{}:36433".format(hostname)
    server = "thread_server.py"
    client = "thread_client.py"
    run_subprocesses(address, server, client, wildcard_server=True)


def test_addressbook_example(cleanup):
    proc = subprocess.Popen(
        [sys.executable, os.path.join(examples_dir, "addressbook.py")]
    )
    ret = proc.wait()
    assert ret == 0


@pytest.mark.skipif(
    sys.platform == "win32",
    reason="""
Asyncio bug with libcapnp timer, likely due to asyncio starving some event loop.
See https://github.com/capnproto/pycapnp/issues/196
""",
)
def test_async_example(cleanup):
    address = "{}:36434".format(hostname)
    server = "async_server.py"
    client = "async_client.py"
    run_subprocesses(address, server, client)


@pytest.mark.skipif(
    sys.platform == "win32",
    reason="""
Asyncio bug with libcapnp timer, likely due to asyncio starving some event loop.
See https://github.com/capnproto/pycapnp/issues/196
""",
)
def test_ssl_async_example(cleanup):
    address = "{}:36435".format(hostname)
    server = "async_ssl_server.py"
    client = "async_ssl_client.py"
    run_subprocesses(address, server, client, ipv4_force=False)


@pytest.mark.skipif(
    sys.platform == "win32",
    reason="""
Asyncio bug with libcapnp timer, likely due to asyncio starving some event loop.
See https://github.com/capnproto/pycapnp/issues/196
""",
)
def test_ssl_reconnecting_async_example(cleanup):
    address = "{}:36436".format(hostname)
    server = "async_ssl_server.py"
    client = "async_reconnecting_ssl_client.py"
    run_subprocesses(address, server, client, ipv4_force=False)


def test_async_ssl_calculator_example(cleanup):
    address = "{}:36437".format(hostname)
    server = "async_ssl_calculator_server.py"
    client = "async_ssl_calculator_client.py"
    run_subprocesses(address, server, client, ipv4_force=False)
