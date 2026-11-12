import { ApiProvider, SessionProvider, webStorage } from "@shop/api-client";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import { App } from "./App";

const baseUrl = import.meta.env.VITE_API_URL || window.location.origin;

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ApiProvider baseUrl={baseUrl} storage={webStorage(window.localStorage)}>
      <App />
    </ApiProvider>
  </StrictMode>,
);
