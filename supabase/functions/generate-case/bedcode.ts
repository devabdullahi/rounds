// The case id, shown to the student as the patient's bed. Kept out of index.ts so it's testable.

/** Two letters and three digits ("KM482"). Letters that read like digits (I, O, Q) are left out.
 *  23 × 23 × 900 ≈ 476,000 codes keeps collisions rare across every student's cases, and
 *  generate-case retries the few that happen. */
export function bedCode(random: () => number = Math.random): string {
  const letters = "ABCDEFGHJKLMNPRSTUVWXYZ";
  const letter = () => letters[Math.floor(random() * letters.length)];
  return letter() + letter() + String(Math.floor(random() * 900) + 100);
}
