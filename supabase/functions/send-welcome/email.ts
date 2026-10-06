// The welcome email: a thank-you for signing up, plus a receipt once Rounds takes payments.
// Design: the "Welcome email" canvas. Inline styles only, since mail apps drop <style> blocks.

/** A purchase to show under the welcome. Filled from Apple's purchase notifications once
 *  subscriptions exist; until then the welcome goes out without one. */
export interface Receipt {
  date: string;
  orderId: string;
  plan: string;
  period: string;
  renews: string;
  price: string;
  tax: string;
  total: string;
}

/** The first name to greet by. Account metadata is client-written, so anything that isn't a short,
 *  plain name (a link, a long string) is dropped rather than echoed into someone's inbox. */
export function greetingName(fullName: string): string {
  const first = fullName.trim().split(/\s+/)[0] ?? "";
  return /^[\p{L}][\p{L}'\u2019-]{0,39}$/u.test(first) ? first : "";
}

export function welcomeEmail(to: string, name: string, receipt?: Receipt) {
  const first = greetingName(name);
  const greeting = first ? `Welcome to Rounds, ${first}` : "Welcome to Rounds";
  const safe = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

  const receiptHtml = receipt ? `
    <div style="margin:30px 36px 0;padding-top:24px;border-top:1px solid #E3E4EA">
      <table role="presentation" width="100%" style="border-collapse:collapse;font-size:15px">
        <tr><td style="font-size:18px;font-weight:700">Receipt</td><td align="right" style="font-size:13px;color:#6C6F7C">${safe(receipt.date)}</td></tr>
        <tr><td style="padding:9px 0;color:#6C6F7C">Order ID</td><td align="right">${safe(receipt.orderId)}</td></tr>
        <tr><td style="padding:9px 0;color:#6C6F7C">Account</td><td align="right">${safe(to)}</td></tr>
        <tr><td style="padding:9px 0;color:#6C6F7C">Paid with</td><td align="right">Apple App Store</td></tr>
        <tr><td style="padding:14px 0 4px;border-top:1px solid #E3E4EA"><b>Rounds ${safe(receipt.plan)}</b><br><span style="font-size:13px;color:#6C6F7C">${safe(receipt.period)} &middot; renews ${safe(receipt.renews)}</span></td><td align="right" valign="top" style="padding-top:14px;border-top:1px solid #E3E4EA">${safe(receipt.price)}</td></tr>
        <tr><td style="padding:4px 0;color:#6C6F7C">Tax</td><td align="right" style="color:#6C6F7C">${safe(receipt.tax)}</td></tr>
        <tr><td style="padding-top:12px;font-weight:700;border-top:1px solid #E3E4EA">Total</td><td align="right" style="padding-top:12px;font-weight:700;border-top:1px solid #E3E4EA">${safe(receipt.total)}</td></tr>
      </table>
      <p style="margin:18px 0 0;font-size:13px;line-height:1.6;color:#6C6F7C">Apple handles your payment and sends its own receipt. To change or cancel your plan, open Settings &rsaquo; your name &rsaquo; Subscriptions on your iPhone.</p>
    </div>` : "";

  const html = `<!doctype html><html><body style="margin:0;background:#F5F6FB">
  <div style="max-width:600px;margin:0 auto;padding:24px;font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;color:#161929">
    <div style="border-radius:18px;background:#FFFFFF;overflow:hidden">
      <div style="padding:32px 36px 8px">
        <p style="margin:0;font-size:16px;font-weight:700;color:#028B4F">Rounds</p>
        <h1 style="margin:22px 0 0;font-size:26px;line-height:1.2">${safe(greeting)}</h1>
        <p style="margin:14px 0 0;font-size:16px;line-height:1.6;color:#434755">Thanks for signing up. Your account is ready, and your first patient is waiting in the app.</p>
      </div>${receiptHtml}
      <div style="margin-top:30px;padding:20px 36px 26px;background:#F5F6FB;font-size:12px;line-height:1.6;color:#6C6F7C">
        Questions? Reply to this email.<br>Rounds is for practice and isn't medical advice. Every patient is fictional.
      </div>
    </div>
  </div></body></html>`;

  const text = [
    greeting,
    "",
    "Thanks for signing up. Your account is ready, and your first patient is waiting in the app.",
    receipt ? `\nReceipt ${receipt.date}\nOrder ID: ${receipt.orderId}\nRounds ${receipt.plan} (${receipt.period}): ${receipt.price}\nTax: ${receipt.tax}\nTotal: ${receipt.total}\nApple handles your payment and sends its own receipt.` : "",
    "",
    "Questions? Reply to this email.",
    "Rounds is for practice and isn't medical advice. Every patient is fictional.",
  ].join("\n");

  return { to, subject: greeting, html, text };
}
