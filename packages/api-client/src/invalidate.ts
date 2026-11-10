import { useQueryClient } from '@tanstack/react-query';

export const useInvalidate = (...prefixes: string[]) => {
  const queryClient = useQueryClient();

  return () =>
    queryClient.invalidateQueries({
      predicate: ({ queryKey }) => {
        const path = queryKey[1];
        return typeof path === 'string' && prefixes.some((prefix) => path.startsWith(prefix));
      },
    });
};
