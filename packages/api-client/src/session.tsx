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
}

export interface SessionStore {
  getToken: () => string | null;
  setToken: (token: string) => void;
  clear: () => void;
  subscribe: (listener: () => void) => () => void;
}

export interface Session extends SessionStore {
  token: string | null;
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
});

export const createSessionStore = (
  storage: SessionStorage = memoryStorage(),
): SessionStore => {
  const listeners = new Set<() => void>();
  const notify = () => listeners.forEach((listener) => listener());

  return {
    getToken: storage.get,
    setToken: (token) => {
      storage.set(token);
      notify();
    },
    clear: () => {
      storage.remove();
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
  return { ...store, token, isAuthenticated: token !== null };
};

export const useSignOut = () => {
  const { clear } = useSessionStore();
  const queryClient = useQueryClient();

  return useCallback(() => {
    clear();
    queryClient.clear();
  }, [clear, queryClient]);
};
