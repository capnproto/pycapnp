#include <kj/async.h>
#include <kj/async-io.h>

using namespace kj;

class PyFdListener {
public:
  virtual void add_reader(int, void (*cb)(void* data), void* data) = 0;
  virtual void remove_reader(int) = 0;
  virtual void add_writer(int, void (*cb)(void* data), void* data) = 0;
  virtual void remove_writer(int) = 0;
  virtual Canceler* getCanceler() = 0;
};

class PyLowLevelAsyncIoProvider final: public kj::LowLevelAsyncIoProvider {
public:
  PyLowLevelAsyncIoProvider(PyFdListener *fdListener,
                            kj::Timer* timer);

  kj::Own<kj::AsyncInputStream> wrapInputFd(Fd fd, uint flags = 0);
  kj::Own<kj::AsyncOutputStream> wrapOutputFd(Fd fd, uint flags = 0);
  kj::Own<kj::AsyncIoStream> wrapSocketFd(Fd fd, uint flags = 0);
  kj::Promise<kj::Own<kj::AsyncIoStream>> wrapConnectingSocketFd(
            Fd fd, const struct sockaddr* addr, uint addrlen, uint flags = 0);
  kj::Timer& getTimer();
  kj::Own<kj::ConnectionReceiver> wrapListenSocketFd(Fd fd, NetworkFilter& filter, uint flags = 0);

 private:
  PyFdListener *fdListener;
  kj::Timer *timer;
};
