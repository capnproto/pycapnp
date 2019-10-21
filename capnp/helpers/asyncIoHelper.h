#pragma once

#include "kj/async.h"
#include "kj/async-io.h"

class AsyncIoStreamReadHelper {
public:
  AsyncIoStreamReadHelper(kj::AsyncIoStream * _stream, kj::WaitScope * _scope, size_t bufsize) {
    io_stream = _stream;
    wait_scope = _scope;
    ready = false;
    buffer_read_size = 0;
    buffer = new unsigned char[bufsize];
    promise = io_stream->read(buffer, 1, bufsize);
  }

  ~AsyncIoStreamReadHelper() {
    delete[] buffer;
  }

  bool poll() {
    bool result = promise.poll(*wait_scope);
    if (result) {
      ready = true;
      buffer_read_size = promise.wait(*wait_scope);
    }
    return result;
  }

  size_t read_size() {
    if (!ready) {
      return 0;
    }
    return buffer_read_size;
  }

  void * read_buffer() {
    if (!ready) {
      return 0;
    }
    return buffer;
  }

private:
  kj::AsyncIoStream * io_stream;
  kj::WaitScope * wait_scope;
  kj::Promise<size_t> promise = nullptr;

  unsigned char *buffer;
  size_t buffer_read_size;

  bool ready;
};
