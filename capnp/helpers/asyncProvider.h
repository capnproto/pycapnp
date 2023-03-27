#include <kj/async.h>
#include <kj/async-io.h>

class PyLowLevelAsyncIoProvider final: public kj::LowLevelAsyncIoProvider {
public:
  PyLowLevelAsyncIoProvider(void (*ar)(int, void (*cb)(void* data), void* data),
                            void (*rr)(int),
                            void (*aw)(int, void (*cb)(void* data), void* data),
                            void (*rw)(int));

  kj::Own<kj::AsyncInputStream> wrapInputFd(Fd fd, uint flags = 0);
  kj::Own<kj::AsyncOutputStream> wrapOutputFd(Fd fd, uint flags = 0);
  kj::Own<kj::AsyncIoStream> wrapSocketFd(Fd fd, uint flags = 0);
  kj::Promise<kj::Own<kj::AsyncIoStream>> wrapConnectingSocketFd(
            Fd fd, const struct sockaddr* addr, uint addrlen, uint flags = 0);
  kj::Timer& getTimer();
  kj::Own<kj::ConnectionReceiver> wrapListenSocketFd(Fd fd, NetworkFilter& filter, uint flags = 0);

 private:
  void (*add_reader)(int, void (*cb)(void* data), void* data);
  void (*remove_reader)(int);
  void (*add_writer)(int, void (*cb)(void* data), void* data);
  void (*remove_writer)(int);
};
