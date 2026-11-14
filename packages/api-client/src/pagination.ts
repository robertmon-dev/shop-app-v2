export const nextPage = (
  body: { meta?: { next_page?: number | null } } | undefined,
) => body?.meta?.next_page ?? undefined;
