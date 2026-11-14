/**
 * Builds a `refetchInterval` callback that keeps refetching while a resource
 * is still settling (e.g. waiting for a Stripe webhook), and stops on its
 * own once the latest fetched data reaches a terminal state.
 */
export const pollWhile =
  <T>(isSettling: (data: T | undefined) => boolean, intervalMs = 3000) =>
  (query: { state: { data?: T } }) =>
    isSettling(query.state.data) ? intervalMs : false;
