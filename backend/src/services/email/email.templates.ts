import type {
  AccountCreatedEmailParams,
  OTPEmailParams,
  PasswordChangedEmailParams,
  RenderedEmailContent,
  SecurityNotificationParams,
  WelcomeEmailParams,
} from "./email.types.ts";

const BRAND = {
  primaryTeal: "#2E8B7A",
  darkTeal: "#0F5C57",
  coral: "#FF8A65",
  gold: "#E8C07D",
  creamBg: "#F8F6F2",
  cardBg: "#FFFFFF",
  textPrimary: "#1E292B",
  textSecondary: "#5A6B6E",
  border: "#E6ECEA",
};

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function formatDateTime(date: Date): string {
  return date.toLocaleString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    timeZoneName: "short",
  });
}

function renderBaseLayout(options: {
  preheader: string;
  title: string;
  accentColor?: string;
  bodyHtml: string;
}): string {
  const accent = options.accentColor || BRAND.primaryTeal;
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escapeHtml(options.title)}</title>
</head>
<body style="margin:0;padding:0;background-color:${BRAND.creamBg};font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:${BRAND.textPrimary};">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">${escapeHtml(options.preheader)}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${BRAND.creamBg};padding:28px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background-color:${BRAND.cardBg};border-radius:16px;border:1px solid ${BRAND.border};overflow:hidden;">
          <tr>
            <td style="background-color:${BRAND.darkTeal};padding:22px 28px;border-bottom:4px solid ${accent};">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td>
                    <span style="font-size:21px;font-weight:700;color:#FFFFFF;letter-spacing:-0.3px;">PetMate</span>
                    <span style="display:block;font-size:12px;color:#CBE3DF;margin-top:2px;">Trusted Pet Care &amp; Discovery</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:28px;">
              ${options.bodyHtml}
            </td>
          </tr>
          <tr>
            <td style="padding:18px 28px;background-color:#FAF9F6;border-top:1px solid ${BRAND.border};font-size:12px;line-height:1.5;color:${BRAND.textSecondary};">
              <p style="margin:0 0 6px 0;">This is an automated security and account message from PetMate.</p>
              <p style="margin:0;">If you need help, please contact PetMate support through the app.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

export function buildOTPEmail(params: OTPEmailParams): RenderedEmailContent {
  const expiry = params.expiresInMinutes ?? 5;
  const greetingName = params.displayName?.trim()
    ? escapeHtml(params.displayName.trim())
    : "Pet Parent";
  const safeOtp = escapeHtml(params.otp);

  const subject = "Your PetMate password reset code";

  const bodyHtml = `
    <h1 style="margin:0 0 12px 0;font-size:20px;line-height:1.3;color:${BRAND.darkTeal};">Reset your PetMate password</h1>
    <p style="margin:0 0 14px 0;font-size:15px;line-height:1.6;color:${BRAND.textPrimary};">Hi ${greetingName},</p>
    <p style="margin:0 0 18px 0;font-size:15px;line-height:1.6;color:${BRAND.textSecondary};">
      Use the 6-digit verification code below to reset your PetMate account password. This code expires in <strong>${expiry} minutes</strong> and can only be used once.
    </p>
    <div style="margin:20px 0;padding:18px;background-color:${BRAND.creamBg};border:1px solid ${BRAND.border};border-radius:12px;text-align:center;">
      <span style="display:inline-block;font-size:30px;font-weight:700;letter-spacing:8px;color:${BRAND.darkTeal};font-family:'Courier New',Courier,monospace;">${safeOtp}</span>
    </div>
    <p style="margin:0 0 10px 0;font-size:13px;line-height:1.55;color:${BRAND.textSecondary};">
      For your security, never share this code with anyone. PetMate staff will never ask for your verification code.
    </p>
    <p style="margin:0;font-size:13px;line-height:1.55;color:${BRAND.textSecondary};">
      If you did not request a password reset, you can safely ignore this email. Your password will remain unchanged.
    </p>
  `;

  const html = renderBaseLayout({
    preheader: `Your PetMate verification code is ${params.otp}. Valid for ${expiry} minutes.`,
    title: subject,
    accentColor: BRAND.coral,
    bodyHtml,
  });

  const text = [
    `Hi ${params.displayName?.trim() || "Pet Parent"},`,
    "",
    `Use this 6-digit code to reset your PetMate password: ${params.otp}`,
    `This code expires in ${expiry} minutes and can only be used once.`,
    "",
    "If you did not request a password reset, you can safely ignore this email.",
  ].join("\n");

  return { subject, html, text };
}

export function buildWelcomeEmail(params: WelcomeEmailParams): RenderedEmailContent {
  const greetingName = params.displayName?.trim()
    ? escapeHtml(params.displayName.trim())
    : "Pet Parent";
  const safeEmail = escapeHtml(params.to);
  const createdDate = formatDateTime(params.createdAt ?? new Date());
  const subject = "Welcome to PetMate! Your journey starts here 🐾";

  const bodyHtml = `
    <h1 style="margin:0 0 12px 0;font-size:21px;line-height:1.3;color:${BRAND.darkTeal};">Welcome to PetMate, ${greetingName}!</h1>
    <p style="margin:0 0 14px 0;font-size:15px;line-height:1.6;color:${BRAND.textPrimary};">
      Your PetMate account has been successfully created and is ready to use.
    </p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:${BRAND.textSecondary};">
      PetMate helps pet owners discover compatible pets nearby, connect safely with fellow pet parents, book veterinary care, and explore trusted pet essentials.
    </p>
    <div style="margin:18px 0;padding:16px;background-color:${BRAND.creamBg};border-left:4px solid ${BRAND.gold};border-radius:8px;">
      <p style="margin:0 0 8px 0;font-size:13px;font-weight:700;color:${BRAND.darkTeal};text-transform:uppercase;letter-spacing:0.4px;">Account Summary</p>
      <p style="margin:0 0 4px 0;font-size:14px;color:${BRAND.textPrimary};"><strong>Name:</strong> ${greetingName}</p>
      <p style="margin:0 0 4px 0;font-size:14px;color:${BRAND.textPrimary};"><strong>Email:</strong> ${safeEmail}</p>
      <p style="margin:0;font-size:14px;color:${BRAND.textPrimary};"><strong>Created:</strong> ${escapeHtml(createdDate)}</p>
    </div>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:${BRAND.textSecondary};">
      <strong>Next step:</strong> Open the PetMate app and complete your pet profile with photos, breed, and personality details so nearby pet owners can discover your companion.
    </p>
    <p style="margin:0;font-size:13px;line-height:1.55;color:${BRAND.textSecondary};">
      Security reminder: If you did not create this PetMate account, please secure your email account and contact support immediately.
    </p>
  `;

  const html = renderBaseLayout({
    preheader: "Your PetMate account is ready. Complete your pet profile to start discovering nearby pets.",
    title: subject,
    accentColor: BRAND.primaryTeal,
    bodyHtml,
  });

  const text = [
    `Welcome to PetMate, ${params.displayName?.trim() || "Pet Parent"}!`,
    "",
    "Your PetMate account has been successfully created.",
    "PetMate helps pet owners discover compatible pets nearby and connect with other pet parents.",
    "",
    `Name: ${params.displayName?.trim() || "Pet Parent"}`,
    `Email: ${params.to}`,
    `Created: ${createdDate}`,
    "",
    "Open the PetMate app to complete your pet profile and start exploring.",
    "If you did not create this account, please contact PetMate support.",
  ].join("\n");

  return { subject, html, text };
}

export function buildAccountCreatedEmail(
  params: AccountCreatedEmailParams
): RenderedEmailContent {
  const greetingName = params.displayName?.trim()
    ? escapeHtml(params.displayName.trim())
    : "Pet Parent";
  const safeEmail = escapeHtml(params.to);
  const createdDate = formatDateTime(params.createdAt ?? new Date());
  const subject = "Your PetMate account details";

  const bodyHtml = `
    <h1 style="margin:0 0 12px 0;font-size:20px;line-height:1.3;color:${BRAND.darkTeal};">Account Confirmation</h1>
    <p style="margin:0 0 14px 0;font-size:15px;line-height:1.6;color:${BRAND.textPrimary};">Hi ${greetingName},</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:${BRAND.textSecondary};">
      Here are the details for your newly created PetMate account:
    </p>
    <div style="margin:16px 0;padding:16px;background-color:${BRAND.creamBg};border:1px solid ${BRAND.border};border-radius:10px;">
      <p style="margin:0 0 6px 0;font-size:14px;color:${BRAND.textPrimary};"><strong>Display Name:</strong> ${greetingName}</p>
      <p style="margin:0 0 6px 0;font-size:14px;color:${BRAND.textPrimary};"><strong>Registered Email:</strong> ${safeEmail}</p>
      <p style="margin:0;font-size:14px;color:${BRAND.textPrimary};"><strong>Account Created:</strong> ${escapeHtml(createdDate)}</p>
    </div>
    <p style="margin:0 0 12px 0;font-size:14px;line-height:1.6;color:${BRAND.textSecondary};">
      You can sign in anytime using the PetMate mobile app with your registered email address.
    </p>
    <p style="margin:0;font-size:13px;line-height:1.55;color:${BRAND.textSecondary};">
      Security reminder: Keep your login credentials private and never share verification codes with anyone.
    </p>
  `;

  const html = renderBaseLayout({
    preheader: "Your PetMate account confirmation and registration details.",
    title: subject,
    accentColor: BRAND.primaryTeal,
    bodyHtml,
  });

  const text = [
    `Hi ${params.displayName?.trim() || "Pet Parent"},`,
    "",
    "Your PetMate account has been created.",
    `Display Name: ${params.displayName?.trim() || "Pet Parent"}`,
    `Registered Email: ${params.to}`,
    `Account Created: ${createdDate}`,
    "",
    "Sign in anytime using the PetMate mobile app.",
  ].join("\n");

  return { subject, html, text };
}

export function buildPasswordChangedEmail(
  params: PasswordChangedEmailParams
): RenderedEmailContent {
  const greetingName = params.displayName?.trim()
    ? escapeHtml(params.displayName.trim())
    : "Pet Parent";
  const changedDate = formatDateTime(params.changedAt ?? new Date());
  const subject = "Your PetMate password has been changed";

  const bodyHtml = `
    <h1 style="margin:0 0 12px 0;font-size:20px;line-height:1.3;color:${BRAND.darkTeal};">Password Changed Successfully</h1>
    <p style="margin:0 0 14px 0;font-size:15px;line-height:1.6;color:${BRAND.textPrimary};">Hi ${greetingName},</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:${BRAND.textSecondary};">
      This is a confirmation that the password for your PetMate account was changed on <strong>${escapeHtml(changedDate)}</strong>.
    </p>
    <div style="margin:16px 0;padding:14px 16px;background-color:#FFF7F4;border-left:4px solid ${BRAND.coral};border-radius:8px;">
      <p style="margin:0;font-size:14px;line-height:1.55;color:${BRAND.textPrimary};">
        <strong>Didn't make this change?</strong><br/>
        If you did not reset or change your password, please reset your password immediately in the PetMate app and contact PetMate support to secure your account.
      </p>
    </div>
    <p style="margin:0;font-size:13px;line-height:1.55;color:${BRAND.textSecondary};">
      Existing active sessions have been revoked for your protection. You can sign back in with your new password.
    </p>
  `;

  const html = renderBaseLayout({
    preheader: "Confirmation that your PetMate account password was changed.",
    title: subject,
    accentColor: BRAND.coral,
    bodyHtml,
  });

  const text = [
    `Hi ${params.displayName?.trim() || "Pet Parent"},`,
    "",
    `Your PetMate account password was changed on ${changedDate}.`,
    "",
    "If you did not make this change, please reset your password immediately and contact PetMate support.",
  ].join("\n");

  return { subject, html, text };
}

export function buildSecurityNotificationEmail(
  params: SecurityNotificationParams
): RenderedEmailContent {
  const greetingName = params.displayName?.trim()
    ? escapeHtml(params.displayName.trim())
    : "Pet Parent";
  const occurredDate = formatDateTime(params.occurredAt ?? new Date());

  const bodyHtml = `
    <h1 style="margin:0 0 12px 0;font-size:20px;line-height:1.3;color:${BRAND.darkTeal};">${escapeHtml(params.headline)}</h1>
    <p style="margin:0 0 14px 0;font-size:15px;line-height:1.6;color:${BRAND.textPrimary};">Hi ${greetingName},</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:${BRAND.textSecondary};">${escapeHtml(params.message)}</p>
    <p style="margin:0 0 16px 0;font-size:13px;color:${BRAND.textSecondary};"><strong>Time:</strong> ${escapeHtml(occurredDate)}</p>
    ${
      params.actionHint
        ? `<div style="margin:16px 0;padding:14px 16px;background-color:${BRAND.creamBg};border-left:4px solid ${BRAND.coral};border-radius:8px;">
            <p style="margin:0;font-size:14px;line-height:1.55;color:${BRAND.textPrimary};">${escapeHtml(params.actionHint)}</p>
          </div>`
        : ""
    }
  `;

  const html = renderBaseLayout({
    preheader: params.headline,
    title: params.subject,
    accentColor: BRAND.coral,
    bodyHtml,
  });

  const text = [
    `Hi ${params.displayName?.trim() || "Pet Parent"},`,
    "",
    params.headline,
    params.message,
    `Time: ${occurredDate}`,
    params.actionHint ? `\n${params.actionHint}` : "",
  ]
    .filter(Boolean)
    .join("\n");

  return { subject: params.subject, html, text };
}
