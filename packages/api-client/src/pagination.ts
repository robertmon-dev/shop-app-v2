/**
 * Kaminari-style pagination meta: `next_page` is `null` once there is no
 * next page. Used as `getNextPageParam` for `useInfiniteQuery`.
 */
export const nextPage = (
  body: { meta?: { next_page?: number | null } } | undefined,
) => body?.meta?.next_page ?? undefined;
