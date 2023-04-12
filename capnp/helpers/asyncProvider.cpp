// Adapted from upstream capnproto implementation in async-io-unix.c++.
// Additionally adapted from the node-capnp implementation:
//  https://github.com/capnproto/node-capnp/blob/node10/src/node-capnp/capnp.cc
//
// Original copyright:

// Copyright (c) 2013-2014 Sandstorm Development Group, Inc. and contributors
// Licensed under the MIT License:
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#include <netinet/tcp.h>
#include <kj/debug.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <kj/io.h>
#include <kj/async.h>
#include <kj/async-io.h>
#include <kj/vector.h>
#include <errno.h>
#include <unistd.h>
#include <capnp/rpc-twoparty.h>
#include <stdlib.h>
#include <sys/uio.h>

#include<iostream>

#include "capnp/helpers/asyncProvider.h"

using namespace kj;

void setNonblocking(int fd) {
#ifdef FIONBIO
  int opt = 1;
  KJ_SYSCALL(ioctl(fd, FIONBIO, &opt));
#else
  int flags;
  KJ_SYSCALL(flags = fcntl(fd, F_GETFL));
  if ((flags & O_NONBLOCK) == 0) {
    KJ_SYSCALL(fcntl(fd, F_SETFL, flags | O_NONBLOCK));
  }
#endif
}

void setCloseOnExec(int fd) {
#ifdef FIOCLEX
  KJ_SYSCALL(ioctl(fd, FIOCLEX));
#else
  int flags;
  KJ_SYSCALL(flags = fcntl(fd, F_GETFD));
  if ((flags & FD_CLOEXEC) == 0) {
    KJ_SYSCALL(fcntl(fd, F_SETFD, flags | FD_CLOEXEC));
  }
#endif
}

static int applyFlags(int fd, uint flags) {
  if (flags & kj::LowLevelAsyncIoProvider::ALREADY_NONBLOCK) {
    KJ_DREQUIRE(fcntl(fd, F_GETFL) & O_NONBLOCK, "You claimed you set NONBLOCK, but you didn't.");
  } else {
    setNonblocking(fd);
  }

  if (flags & kj::LowLevelAsyncIoProvider::TAKE_OWNERSHIP) {
    if (flags & kj::LowLevelAsyncIoProvider::ALREADY_CLOEXEC) {
      KJ_DREQUIRE(fcntl(fd, F_GETFD) & FD_CLOEXEC,
                  "You claimed you set CLOEXEC, but you didn't.");
    } else {
      setCloseOnExec(fd);
    }
  }

  return fd;
}

static constexpr uint NEW_FD_FLAGS =
#if __linux__
    kj::LowLevelAsyncIoProvider::ALREADY_CLOEXEC | kj::LowLevelAsyncIoProvider::ALREADY_NONBLOCK |
#endif
    kj::LowLevelAsyncIoProvider::TAKE_OWNERSHIP;
// We always try to open FDs with CLOEXEC and NONBLOCK already set on Linux, but on other platforms
// this is not possible.


class OwnedFileDescriptor {
public:
  OwnedFileDescriptor(int fd, uint flags,
                      PyFdListener *fdListener)
    : fd(applyFlags(fd, flags)), flags(flags), fdListener(fdListener) {
    readRegistered = false;
    writeRegistered = false;
  }

  ~OwnedFileDescriptor() noexcept(false) {
    fdListener->remove_reader(fd);
    fdListener->remove_writer(fd);

    // Don't use KJ_SYSCALL() here because close() should not be repeated on EINTR.
    if ((flags & kj::LowLevelAsyncIoProvider::TAKE_OWNERSHIP) && close(fd) < 0) {
      KJ_FAIL_SYSCALL("close", errno, fd) {
        // Recoverable exceptions are safe in destructors.
        break;
      }
    }
  }

  kj::Promise<void> onReadable() {
    // TODO: Detect if fd is already readable and return kj::READY_NOW immediately
    KJ_REQUIRE(readRegistered == false, "Must wait for previous event to complete.");
    return fdListener->getCanceler()->wrap(kj::newAdaptedPromise<void, ReadPromiseAdapter>(*this));
  }

  kj::Promise<void> onWritable() {
    // TODO: Detect if fd is already readable and return kj::READY_NOW immediately
    KJ_REQUIRE(writeRegistered == false, "Must wait for previous event to complete.");
    return fdListener->getCanceler()->wrap(kj::newAdaptedPromise<void, WritePromiseAdapter>(*this));
  }

protected:
  const int fd;
  uint flags;
  PyFdListener *fdListener;

private:
  bool readRegistered;
  bool writeRegistered;

  class ReadPromiseAdapter {
  public:
    ReadPromiseAdapter(kj::PromiseFulfiller<void>& fulfiller, OwnedFileDescriptor& ofd)
      : fulfiller(fulfiller), ofd(ofd) {
      ofd.fdListener->add_reader(ofd.fd, &readCallback, (void*)this);
      ofd.readRegistered = true;
    }

    ~ReadPromiseAdapter() {
      ofd.fdListener->remove_reader(ofd.fd);
      ofd.readRegistered = false;
    }

  private:
    kj::PromiseFulfiller<void>& fulfiller;
    OwnedFileDescriptor& ofd;

    static void readCallback(void* data) {
      reinterpret_cast<ReadPromiseAdapter*>(data)->readDone();
    }

    void readDone() {
      fulfiller.fulfill();
    }

  };

  class WritePromiseAdapter {
  public:
    WritePromiseAdapter(kj::PromiseFulfiller<void>& fulfiller, OwnedFileDescriptor& ofd)
      : fulfiller(fulfiller), ofd(ofd) {
      ofd.fdListener->add_writer(ofd.fd, &writeCallback, (void*)this);
      ofd.writeRegistered = true;
    }

    ~WritePromiseAdapter() {
      ofd.fdListener->remove_writer(ofd.fd);
      ofd.writeRegistered = false;
    }

  private:
    kj::PromiseFulfiller<void>& fulfiller;
    OwnedFileDescriptor& ofd;

    static void writeCallback(void* data) {
      reinterpret_cast<WritePromiseAdapter*>(data)->writeDone();
    }

    void writeDone() {
      fulfiller.fulfill();
    }

  };

};

class PyIoStream: public OwnedFileDescriptor, public kj::AsyncIoStream {
  // IoStream implementation on top of pythons asyncio.  This is mostly a copy of the UnixEventPort-based
  // implementation in kj/async-io.c++.
  //
  // TODO(cleanup):  Allow better code sharing between the two.

public:
  PyIoStream(int fd, uint flags, PyFdListener *fdListener)
    : OwnedFileDescriptor(fd, flags, fdListener) {}
  virtual ~PyIoStream() noexcept(false) {}

  kj::Promise<size_t> tryRead(void* buffer, size_t minBytes, size_t maxBytes) override {
    return tryReadInternal(buffer, minBytes, maxBytes, 0);
  }

  Promise<void> write(const void* buffer, size_t size) override {
    ssize_t n;
    KJ_NONBLOCKING_SYSCALL(n = ::write(fd, buffer, size)) {
      // Error.

      // We can't "return kj::READY_NOW;" inside this block because it causes a memory leak due to
      // a bug that exists in both Clang and GCC:
      //   http://gcc.gnu.org/bugzilla/show_bug.cgi?id=33799
      //   http://llvm.org/bugs/show_bug.cgi?id=12286
      goto error;
    }
    if (false) {
    error:
      return kj::READY_NOW;
    }

    if (n < 0) {
      // EAGAIN -- need to wait for writability and try again.
      return onWritable().then([=]() {
        return write(buffer, size);
      });
    } else if (n == size) {
      // All done.
      return READY_NOW;
    } else {
      // Fewer than `size` bytes were written, but we CANNOT assume we're out of buffer space, as
      // Linux is known to return partial reads/writes when interrupted by a signal -- yes, even
      // for non-blocking operations. So, we'll need to write() again now, even though it will
      // almost certainly fail with EAGAIN. See comments in the read path for more info.
      buffer = reinterpret_cast<const byte*>(buffer) + n;
      size -= n;
      return write(buffer, size);
    }
  }

  Promise<void> write(ArrayPtr<const ArrayPtr<const byte>> pieces) override {
    if (pieces.size() == 0) {
      return writeInternal(nullptr, nullptr);
    } else {
      return writeInternal(pieces[0], pieces.slice(1, pieces.size()));
    }
  }

  // TODO: Potentially copy over more api's from capnproto async-io-unix.c++ like
  //       writeWithFds, tryPumpFrom and friends to make certain operations faster

  void shutdownWrite() override {
    // There's no legitimate way to get an AsyncStreamFd that isn't a socket through the
    // UnixAsyncIoProvider interface.
    KJ_SYSCALL(shutdown(fd, SHUT_WR));
  }

  void abortRead() override {
    // There's no legitimate way to get an AsyncStreamFd that isn't a socket through the
    // UnixAsyncIoProvider interface.
    KJ_SYSCALL(shutdown(fd, SHUT_RD));
  }

  kj::Promise<void> whenWriteDisconnected() override {
    // TODO(someday): Implement using some Python API
    return kj::NEVER_DONE;
  }

  // TODO: Potentially copy over capnpro apis like getsockopt, get peername and getFd

private:
  kj::Promise<size_t> tryReadInternal(void* buffer, size_t minBytes, size_t maxBytes,
                                      size_t alreadyRead) {
    // `alreadyRead` is the number of bytes we have already received via previous reads -- minBytes,
    // maxBytes, and buffer have already been adjusted to account for them, but this count must
    // be included in the final return value.

    ssize_t n;
    KJ_NONBLOCKING_SYSCALL(n = ::read(fd, buffer, maxBytes)) {
      // Error.

      // We can't "return kj::READY_NOW;" inside this block because it causes a memory leak due to
      // a bug that exists in both Clang and GCC:
      //   http://gcc.gnu.org/bugzilla/show_bug.cgi?id=33799
      //   http://llvm.org/bugs/show_bug.cgi?id=12286
      goto error;
    }

    if (false) {
    error:
      return alreadyRead;
    }

    if (n < 0) {
      // Read would block.
      return onReadable().then([=]() {
        return tryReadInternal(buffer, minBytes, maxBytes, alreadyRead);
      });
    } else if (n == 0) {
      // EOF -OR- maxBytes == 0.
      return alreadyRead;
    } else if (implicitCast<size_t>(n) >= minBytes) {
      // We read enough to stop here.
      alreadyRead += n;
      return alreadyRead;
    } else {
      // The kernel returned fewer bytes than we asked for (and fewer than we need).

      buffer = reinterpret_cast<byte*>(buffer) + n;
      minBytes -= n;
      maxBytes -= n;
      alreadyRead += n;

      // According to David Klempner, who works on Stubby at Google, we sadly CANNOT assume that
      // we've consumed the whole read buffer here. If a signal is delivered in the middle of a
      // read() -- yes, even a non-blocking read -- it can cause the kernel to return a partial
      // result, with data still in the buffer.
      //     https://bugzilla.kernel.org/show_bug.cgi?id=199131
      //     https://twitter.com/CaptainSegfault/status/1112622245531144194
      //
      // Unfortunately, we have no choice but to issue more read()s until it either tells us EOF
      // or EAGAIN. We used to have an optimization here using observer.atEndHint() (when it is
      // non-null) to avoid a redundant call to read(). Alas...
      return tryReadInternal(buffer, minBytes, maxBytes, alreadyRead);
    }
  }

  kj::Promise<void> writeInternal(kj::ArrayPtr<const kj::byte> firstPiece,
                                  kj::ArrayPtr<const kj::ArrayPtr<const kj::byte>> morePieces) {
    // TODO: Update this function to the upstream code in async-io-unix.c++ once this issue is resolved:
    //       https://github.com/capnproto/capnproto/issues/1658
    KJ_STACK_ARRAY(struct iovec, iov, 1 + morePieces.size(), 16, 128);

    // writev() interface is not const-correct.  :(
    iov[0].iov_base = const_cast<kj::byte*>(firstPiece.begin());
    iov[0].iov_len = firstPiece.size();
    for (uint i = 0; i < morePieces.size(); i++) {
      iov[i + 1].iov_base = const_cast<kj::byte*>(morePieces[i].begin());
      iov[i + 1].iov_len = morePieces[i].size();
    }

    ssize_t writeResult;
    KJ_NONBLOCKING_SYSCALL(writeResult = ::writev(fd, iov.begin(), iov.size())) {
      // Error.

      // We can't "return kj::READY_NOW;" inside this block because it causes a memory leak due to
      // a bug that exists in both Clang and GCC:
      //   http://gcc.gnu.org/bugzilla/show_bug.cgi?id=33799
      //   http://llvm.org/bugs/show_bug.cgi?id=12286
      goto error;
    }
    if (false) {
    error:
      return kj::READY_NOW;
    }

    // A negative result means EAGAIN, which we can treat the same as having written zero bytes.
    size_t n = writeResult < 0 ? 0 : writeResult;

    // Discard all data that was written, then issue a new write for what's left (if any).
    for (;;) {
      if (n < firstPiece.size()) {
        // Only part of the first piece was consumed.  Wait for POLLOUT and then write again.
        firstPiece = firstPiece.slice(n, firstPiece.size());
        return onWritable().then([=]() {
          return writeInternal(firstPiece, morePieces);
        });
      } else if (morePieces.size() == 0) {
        // First piece was fully-consumed and there are no more pieces, so we're done.
        KJ_DASSERT(n == firstPiece.size(), n);
        return kj::READY_NOW;
      } else {
        // First piece was fully consumed, so move on to the next piece.
        n -= firstPiece.size();
        firstPiece = morePieces[0];
        morePieces = morePieces.slice(1, morePieces.size());
      }
    }
  }
};

class PyConnectionReceiver final: public kj::ConnectionReceiver, public OwnedFileDescriptor {
  // Like PyIoStream but for ConnectionReceiver.  This is also largely copied from kj/async-io.c++.

public:
  PyConnectionReceiver(int fd, uint flags, PyFdListener *fdListener)
    : OwnedFileDescriptor(fd, flags, fdListener) {}

  kj::Promise<kj::Own<kj::AsyncIoStream>> accept() override {
    int newFd;

    struct sockaddr_storage addr;
    socklen_t addrlen = sizeof(addr);

  retry:
#if __linux__ && !__BIONIC__
    newFd = ::accept4(fd, reinterpret_cast<struct sockaddr*>(&addr), &addrlen,
                      SOCK_NONBLOCK | SOCK_CLOEXEC);
#else
    newFd = ::accept(fd, reinterpret_cast<struct sockaddr*>(&addr), &addrlen);
#endif

    if (newFd >= 0) {
      kj::AutoCloseFd ownFd(newFd);
      // TODO(perf):  As a hack for the 0.4 release we are always setting
      //   TCP_NODELAY because Nagle's algorithm pretty much kills Cap'n Proto's
      //   RPC protocol.  Later, we should extend the interface to provide more
      //   control over this.  Perhaps write() should have a flag which
      //   specifies whether to pass MSG_MORE.
      int one = 1;
      KJ_SYSCALL_HANDLE_ERRORS(::setsockopt(
            ownFd.get(), IPPROTO_TCP, TCP_NODELAY, (char*)&one, sizeof(one))) {
        case EOPNOTSUPP:
        case ENOPROTOOPT: // (returned for AF_UNIX in cygwin)
#if __FreeBSD__
        case EINVAL: // (returned for AF_UNIX in FreeBSD)
#endif
          break;
        default:
          KJ_FAIL_SYSCALL("setsocketopt(IPPROTO_TCP, TCP_NODELAY)", error);
      }
      return kj::Own<kj::AsyncIoStream>(kj::heap<PyIoStream>(ownFd.release(), NEW_FD_FLAGS, fdListener));
    } else {
      int error = errno;

      switch (error) {
        case EAGAIN:
#if EAGAIN != EWOULDBLOCK
        case EWOULDBLOCK:
#endif
          // Not ready yet.
          return onReadable().then([this]() {
            return accept();
          });

        case EINTR:
        case ENETDOWN:
#ifdef EPROTO
        // EPROTO is not defined on OpenBSD.
        case EPROTO:
#endif
        case EHOSTDOWN:
        case EHOSTUNREACH:
        case ENETUNREACH:
        case ECONNABORTED:
        case ETIMEDOUT:
          // According to the Linux man page, accept() may report an error if the accepted
          // connection is already broken.  In this case, we really ought to just ignore it and
          // keep waiting.  But it's hard to say exactly what errors are such network errors and
          // which ones are permanent errors.  We've made a guess here.
          goto retry;

        default:
          KJ_FAIL_SYSCALL("accept", error);
      }

    }
  }

  uint getPort() override {
    socklen_t addrlen;
    union {
      struct sockaddr generic;
      struct sockaddr_in inet4;
      struct sockaddr_in6 inet6;
    } addr;
    addrlen = sizeof(addr);
    KJ_SYSCALL(::getsockname(fd, &addr.generic, &addrlen));
    switch (addr.generic.sa_family) {
      case AF_INET: return ntohs(addr.inet4.sin_port);
      case AF_INET6: return ntohs(addr.inet6.sin6_port);
      default: return 0;
    }
  }
};

PyLowLevelAsyncIoProvider::PyLowLevelAsyncIoProvider(PyFdListener *fdListener,
                                                     kj::Timer* t) :
  fdListener(fdListener), timer(t) {}

kj::Own<kj::AsyncInputStream> PyLowLevelAsyncIoProvider::wrapInputFd(int fd, uint flags) {
  return kj::heap<PyIoStream>(fd, flags, fdListener);
}
kj::Own<kj::AsyncOutputStream> PyLowLevelAsyncIoProvider::wrapOutputFd(int fd, uint flags) {
  return kj::heap<PyIoStream>(fd, flags, fdListener);
}
kj::Own<kj::AsyncIoStream> PyLowLevelAsyncIoProvider::wrapSocketFd(int fd, uint flags) {
  return kj::heap<PyIoStream>(fd, flags, fdListener);
}
kj::Promise<kj::Own<kj::AsyncIoStream>> PyLowLevelAsyncIoProvider::wrapConnectingSocketFd(
      int fd, const struct sockaddr* addr, uint addrlen, uint flags) {
  // It's important that we construct the AsyncStreamFd first, so that `flags` are honored,
  // especially setting nonblocking mode and taking ownership.
  auto result = kj::heap<PyIoStream>(fd, flags, fdListener);

  // Unfortunately connect() doesn't fit the mold of KJ_NONBLOCKING_SYSCALL, since it indicates
  // non-blocking using EINPROGRESS.
  for (;;) {
    if (::connect(fd, addr, addrlen) < 0) {
      int error = errno;
      if (error == EINPROGRESS) {
        // Fine.
        break;
      } else if (error != EINTR) {
        KJ_FAIL_SYSCALL("connect()", error) { break; }
        return kj::Own<kj::AsyncIoStream>();
      }
    } else {
      // no error
      break;
    }
  }

  auto connected = result->onWritable();
  return connected.then(kj::mvCapture(result,
      [fd](kj::Own<kj::AsyncIoStream>&& stream) {
        int err;
        socklen_t errlen = sizeof(err);
        KJ_SYSCALL(getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &errlen));
        if (err != 0) {
          KJ_FAIL_SYSCALL("connect()", err) { break; }
        }
        return kj::mv(stream);
      }));
}

kj::Own<kj::ConnectionReceiver> PyLowLevelAsyncIoProvider::wrapListenSocketFd(int fd,
    kj::LowLevelAsyncIoProvider::NetworkFilter& filter, uint flags) {
  // TODO(soon): TODO(security): Actually use `filter`. Currently no API is exposed to set a
  //   filter so it's not important yet.
  return kj::heap<PyConnectionReceiver>(fd, flags, fdListener);
}

kj::Timer& PyLowLevelAsyncIoProvider::getTimer() {
  return *timer;
}
