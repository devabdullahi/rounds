import { assertEquals } from "jsr:@std/assert@1";
import { hiddenTests } from "./menu.ts";

const rubric = { unnecessary_tests: [{ id: "chest_x_ray", name: "Chest X-ray", why: null }, { id: "lipase", name: "Lipase", why: null }] };

Deno.test("practice hides the not-indicated tests", () => {
  assertEquals(hiddenTests(rubric, false), ["chest_x_ray", "lipase"]);
});

Deno.test("exam mode hides nothing, decoys included", () => {
  assertEquals(hiddenTests(rubric, true), []);
});
