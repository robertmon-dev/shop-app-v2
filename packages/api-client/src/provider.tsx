import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createContext, useContext, useMemo, type ReactNode } from 'react';

import { createApiClient, type ApiClient, type ApiClientOptions } from './client';

const ApiContext = createContext<ApiClient | null>(null);

interface ApiProviderProps extends ApiClientOptions {
  queryClient?: QueryClient;
  children: ReactNode;
}

export const ApiProvider = ({ baseUrl, getToken, queryClient, children }: ApiProviderProps) => {
  const client = useMemo(() => createApiClient({ baseUrl, getToken }), [baseUrl, getToken]);
  const queries = useMemo(() => queryClient ?? new QueryClient(), [queryClient]);

  return (
    <ApiContext.Provider value={client}>
      <QueryClientProvider client={queries}>{children}</QueryClientProvider>
    </ApiContext.Provider>
  );
};

export const useApi = (): ApiClient => {
  const client = useContext(ApiContext);
  if (!client) throw new Error('useApi must be used inside <ApiProvider>');
  return client;
};
