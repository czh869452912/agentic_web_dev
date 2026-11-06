export function installAbortSignalAny() {
  if (typeof AbortSignal.any === 'function') return;
  const aborted = Object.getOwnPropertyDescriptor(AbortSignal.prototype, 'aborted').get;
  const registry = typeof FinalizationRegistry === 'function'
    ? new FinalizationRegistry(cleanup => cleanup()) : undefined;
  const controllers = new WeakMap();

  function cleanupFor(listeners) {
    return () => {
      for (const [signal, listener] of listeners) signal.removeEventListener('abort', listener);
      listeners.clear();
    };
  }

  function listen(weak, sources, cleanup) {
    for (const signal of sources.keys()) {
      const listener = () => {
        const target = weak.deref();
        cleanup();
        if (target) {
          registry?.unregister(target.signal);
          controllers.delete(target.signal);
          target.abort(signal.reason);
        }
      };
      sources.set(signal, listener);
      signal.addEventListener('abort', listener, { once: true });
    }
  }

  Object.defineProperty(AbortSignal, 'any', {
    configurable: true,
    writable: true,
    value: function any(signals) {
      // WebIDL accepts a sequence of real AbortSignals, not signal-shaped objects.
      if (signals == null || typeof signals[Symbol.iterator] !== 'function') {
        throw new TypeError('AbortSignal.any requires an iterable of AbortSignals');
      }
      const sources = Array.from(signals);
      for (const signal of sources) aborted.call(signal);
      const controller = new AbortController();
      for (const signal of sources) {
        if (signal.aborted) {
          controller.abort(signal.reason);
          return controller.signal;
        }
      }
      const listeners = new Map();
      const weak = new WeakRef(controller);
      const cleanup = cleanupFor(listeners);
      for (const signal of sources) listeners.set(signal, undefined);
      listen(weak, listeners, cleanup);
      // Keep the controller alive while the returned signal is in use, but do not
      // keep an abandoned composite alive through its source listeners.
      controllers.set(controller.signal, controller);
      registry?.register(controller.signal, cleanup, controller.signal);
      return controller.signal;
    },
  });
}
