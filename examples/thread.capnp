@0xf5745ea9c82baa3a;

interface Example {
  interface StatusSubscriber {
    status @0 (value: Bool);
    # Call the function on the given parameters.
  }

  longRunning @0 () -> (value: Bool);
  subscribeStatus @1 (subscriber: StatusSubscriber);
  alive @2 () -> (value: Bool);
}
