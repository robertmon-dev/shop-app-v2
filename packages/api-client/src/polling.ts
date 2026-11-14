export const pollWhile =
  <T>(isSettling: (data: T | undefined) => boolean, intervalMs = 3000) =>
  (query: { state: { data?: T } }) =>
    isSettling(query.state.data) ? intervalMs : false;
