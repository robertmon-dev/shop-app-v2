import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

export interface SessionStorage {
  get: () => string | null;
  set: (token: string) => void;
  remove: () => void;
}

export interface Session {
  token: string | null;
  isAuthenticated: boolean;
  setToken: (token: string) => void;
  clear: () => void;
  getToken: () => string | null;
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

const SessionContext = createContext<Session | null>(null);

interface SessionProviderProps {
  storage?: SessionStorage;
  children: ReactNode;
}

export const SessionProvider = ({
  storage,
  children,
}: SessionProviderProps) => {
  const store = useMemo(() => storage ?? memoryStorage(), [storage]);
  const [token, setState] = useState(() => store.get());
  const latest = useRef(token);

  const setToken = useCallback(
    (next: string) => {
      latest.current = next;
      store.set(next);
      setState(next);
    },
    [store],
  );

  const clear = useCallback(() => {
    latest.current = null;
    store.remove();
    setState(null);
  }, [store]);

  const getToken = useCallback(() => latest.current, []);

  const value = useMemo(
    () => ({
      token,
      isAuthenticated: token !== null,
      setToken,
      clear,
      getToken,
    }),
    [token, setToken, clear, getToken],
  );

  return (
    <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
  );
};

export const useSession = (): Session => {
  const session = useContext(SessionContext);
  if (!session)
    throw new Error("useSession must be used inside <SessionProvider>");
  return session;
};
