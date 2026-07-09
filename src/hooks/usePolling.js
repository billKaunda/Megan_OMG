import { useEffect, useRef } from 'react';

/**
 * Calls `callback` immediately and then every `interval` milliseconds.
 * Cleans up the interval when the component unmounts or dependencies change.
 */
const usePolling = (callback, interval = 5000, enabled = true) => {
  const savedCallback = useRef(callback);

  useEffect(() => {
    savedCallback.current = callback;
  }, [callback]);

  useEffect(() => {
    if (!enabled) return;

    savedCallback.current();
    const id = setInterval(() => savedCallback.current(), interval);
    return () => clearInterval(id);
  }, [interval, enabled]);
};

export default usePolling;
