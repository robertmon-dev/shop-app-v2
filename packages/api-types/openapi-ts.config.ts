import { defineConfig } from "@hey-api/openapi-ts";

export default defineConfig({
  input: "../../apps/api/swagger/v1/swagger.yaml",
  output: { path: "src/zod", clean: true },
  plugins: [{ name: "zod", requests: true, responses: true }],
});
