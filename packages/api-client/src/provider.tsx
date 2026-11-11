import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createContext, useContext, useMemo, type ReactNode } from "react";

import { createApiClient, type ApiClient } from "./client";
import { SessionProvider, useSession, type SessionStorage } from "./session";

const ApiContext = createContext<ApiClient | null>(null);

interface ApiProviderProps {
  baseUrl: string;
  validate?: boolean;
  storage?: SessionStorage;
  queryClient?: QueryClient;
  children: ReactNode;
}

const ClientProvider = ({
  baseUrl,
  validate,
  queryClient,
  children,
}: Omit<ApiProviderProps, "storage">) => {
  const { getToken, clear } = useSession();
  const client = useMemo(
    () =>
      createApiClient({ baseUrl, validate, getToken, onUnauthorized: clear }),
    [baseUrl, validate, getToken, clear],
  );
  const queries = useMemo(
    () => queryClient ?? new QueryClient(),
    [queryClient],
  );

  return (
    <ApiContext.Provider value={client}>
      <QueryClientProvider client={queries}>{children}</QueryClientProvider>
    </ApiContext.Provider>
  );
};

export const ApiProvider = ({ storage, ...props }: ApiProviderProps) => (
  <SessionProvider storage={storage}>
    <ClientProvider {...props} />
  </SessionProvider>
);

export const useApi = (): ApiClient => {
  const client = useContext(ApiContext);
  if (!client) throw new Error("useApi must be used inside <ApiProvider>");
  return client;
};
