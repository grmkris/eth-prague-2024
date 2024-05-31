import { swaggerUI } from "@hono/swagger-ui";
import { OpenAPIHono } from "@hono/zod-openapi";
import application from "routes/router";

const app = new OpenAPIHono();

app.route("/", application);

app.get("/health", (c) => c.text("OK"));
app.doc("/doc", {
  openapi: "3.0.0",
  info: {
    version: "1.0.0",
    title: "api1",
  },
});
app.get("/ui", swaggerUI({ url: "/doc" }));

export default {
  port: 3000,
  fetch: app.fetch,
};