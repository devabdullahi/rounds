import { assertEquals, assertMatch } from "jsr:@std/assert@1";
import { seeded } from "../_shared/labs.ts";
import { bedCode } from "./bedcode.ts";

Deno.test("bed codes are two clear letters and three digits", () => {
  const random = seeded(3);
  for (let i = 0; i < 500; i++) assertMatch(bedCode(random), /^[A-HJ-NPR-Z]{2}[1-9][0-9]{2}$/);
});

Deno.test("bed codes rarely repeat", () => {
  const random = seeded(11);
  const codes = Array.from({ length: 1000 }, () => bedCode(random));
  // With ~476,000 codes, 1,000 draws expect about one repeat; the old 2,070 would give hundreds.
  assertEquals(new Set(codes).size >= 990, true);
});

Deno.test("bed codes cover the ends of the range", () => {
  assertEquals(bedCode(() => 0), "AA100");
  assertEquals(bedCode(() => 0.999999), "ZZ999");
});
