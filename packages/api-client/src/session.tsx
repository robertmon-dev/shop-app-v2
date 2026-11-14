import { useQueryClient } from "@tanstack/react-query";
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useSyncExternalStore,
  type ReactNode,
} from "react";

export interface SessionStorage {
  get: () => string | null;
  set: (token: string) => void;
  remove: () => void;
  subscribe?: (listener: () => void) => () => void;
}

export interface SessionStore {
  getToken: () => string | null;
  getExpiresAt: () => number | null;
  setToken: (token: string) => void;
  clear: () => void;
  subscribe: (listener: () => void) => () => void;
}

export interface Session extends SessionStore {
  token: string | null;
  expiresAt: number | null;
  isAuthenticated: boolean;
}

export const memoryStorage = (): SessionStorage => {
  let value: string | null = null;
  return {
    get: () => value,
    set: (token) => {
      value = token;
    },
    remove: () => {
      value = null;
    },
  };
};

export const webStorage = (
  storage: Storage,
  key = "session_token",
): SessionStorage => ({
  get: () => storage.getItem(key),
  set: (token) => storage.setItem(key, token),
  remove: () => storage.removeItem(key),
  subscribe: (listener) => {
    const onStorage = (event: StorageEvent) => {
      if (event.storageArea === storage && event.key === key) listener();
    };
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  },
});

/** Reads the `exp` claim (seconds since epoch) out of a JWT, without verifying it. */
const decodeExpiry = (token: string): number | null => {
  try {
    const payload = token.split(".")[1];
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const { exp } = JSON.parse(atob(base64)) as { exp?: unknown };
    return typeof exp === "number" ? exp * 1000 : null;
  } catch {
    return null;
  }
};

export const createSessionStore = (
  storage: SessionStorage = memoryStorage(),
): SessionStore => {
  const listeners = new Set<() => void>();
  const notify = () => listeners.forEach((listener) => listener());

  let expiresAt: number | null = null;
  let expiryTimer: ReturnType<typeof setTimeout> | undefined;

  const clearExpiryTimer = () => {
    clearTimeout(expiryTimer);
    expiryTimer = undefined;
  };

  // Schedules the token to be dropped client-side once it expires, since the
  // API never refreshes it and otherwise we'd only notice on the next 401.
  const scheduleExpiry = (token: string | null) => {
    clearExpiryTimer();
    expiresAt = token ? decodeExpiry(token) : null;
    if (expiresAt === null) return;

    const delay = expiresAt - Date.now();
    if (delay <= 0) {
      storage.remove();
      expiresAt = null;
      return;
    }
    expiryTimer = setTimeout(() => {
      storage.remove();
      expiresAt = null;
      notify();
    }, delay);
  };

  // Covers a token already persisted from a previous visit.
  scheduleExpiry(storage.get());

  // Another tab signing in/out should be reflected here too.
  storage.subscribe?.(() => {
    scheduleExpiry(storage.get());
    notify();
  });

  return {
    getToken: storage.get,
    getExpiresAt: () => expiresAt,
    setToken: (token) => {
      storage.set(token);
      scheduleExpiry(token);
      notify();
    },
    clear: () => {
      storage.remove();
      clearExpiryTimer();
      expiresAt = null;
      notify();
    },
    subscribe: (listener) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
  };
};

const SessionContext = createContext<SessionStore | null>(null);

interface SessionProviderProps {
  storage?: SessionStorage;
  children: ReactNode;
}

export const SessionProvider = ({
  storage,
  children,
}: SessionProviderProps) => {
  const store = useMemo(() => createSessionStore(storage), [storage]);
  return (
    <SessionContext.Provider value={store}>{children}</SessionContext.Provider>
  );
};

export const useSessionStore = (): SessionStore => {
  const store = useContext(SessionContext);
  if (!store)
    throw new Error("useSession must be used inside <SessionProvider>");
  return store;
};

export const useSession = (): Session => {
  const store = useSessionStore();
  const token = useSyncExternalStore(
    store.subscribe,
    store.getToken,
    () => null,
  );
  const expiresAt = useSyncExternalStore(
    store.subscribe,
    store.getExpiresAt,
    () => null,
  );
  return { ...store, token, expiresAt, isAuthenticated: token !== null };
};

export const useSignOut = () => {
  const { clear } = useSessionStore();
  const queryClient = useQueryClient();

  return useCallback(() => {
    clear();
    queryClient.clear();
  }, [clear, queryClient]);
};
