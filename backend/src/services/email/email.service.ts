import { getDefaultFromAddress, getResendClient } from "../../config/resend.ts";
import {
  buildAccountCreatedEmail,
  buildOTPEmail,
  buildPasswordChangedEmail,
  buildSecurityNotificationEmail,
  buildWelcomeEmail,
} from "./email.templates.ts";
import type {
  AccountCreatedEmailParams,
  EmailSendResult,
  OTPEmailParams,
  PasswordChangedEmailParams,
  RenderedEmailContent,
  SecurityNotificationParams,
  WelcomeEmailParams,
} from "./email.types.ts";

export interface EmailTransport {
  send: (payload: {
    from: string;
    to: string;
    subject: string;
    html: string;
    text: string;
  }) => Promise<{ id?: string; error?: { message?: string; name?: string; statusCode?: number } | null }>;
}

let customTransport: EmailTransport | null = null;

/**
 * Allows unit tests to inject a deterministic in-memory transport without hitting Resend's API.
 */
export const setEmailTransportForTesting = (transport: EmailTransport | null): void => {
  customTransport = transport;
};

function isTestingDomainRestriction(message: string): boolean {
  const lower = message.toLowerCase();
  return (
    lower.includes("testing emails") ||
    lower.includes("verify a domain") ||
    lower.includes("own email address")
  );
}

async function sendTransactionalEmail(
  to: string,
  content: RenderedEmailContent,
  category: string
): Promise<EmailSendResult> {
  const normalizedTo = to.trim().toLowerCase();
  const from = getDefaultFromAddress();

  if (customTransport) {
    try {
      const response = await customTransport.send({
        from,
        to: normalizedTo,
        subject: content.subject,
        html: content.html,
        text: content.text,
      });
      if (response.error) {
        const msg = response.error.message || "Email provider error";
        return {
          delivered: false,
          errorCode: response.error.name || "PROVIDER_ERROR",
          errorMessage: msg,
          isTestingRestriction: isTestingDomainRestriction(msg),
        };
      }
      return { delivered: true, messageId: response.id };
    } catch (err: any) {
      return {
        delivered: false,
        errorCode: "TRANSPORT_EXCEPTION",
        errorMessage: err?.message || "Failed to send email",
      };
    }
  }

  const client = getResendClient();
  if (!client) {
    console.warn(
      `⚠️ [EmailService] Resend is not configured (RESEND_API_KEY missing). Skipped ${category} email.`
    );
    return {
      delivered: false,
      errorCode: "RESEND_NOT_CONFIGURED",
      errorMessage: "Email service is not configured",
    };
  }

  try {
    const { data, error } = await client.emails.send({
      from,
      to: normalizedTo,
      subject: content.subject,
      html: content.html,
      text: content.text,
    });

    if (error) {
      const errMsg = error.message || "Resend rejected the email request";
      const restricted = isTestingDomainRestriction(errMsg);
      if (restricted) {
        console.error(
          `❌ [EmailService] Resend testing-domain restriction blocked ${category} email (${error.name}): ` +
            "onboarding@resend.dev can only deliver to the email address of your Resend account. " +
            "Verify a custom domain in Resend and update RESEND_FROM_EMAIL to send to other recipients."
        );
      } else {
        console.error(
          `❌ [EmailService] Failed to send ${category} email (${error.name || "RESEND_ERROR"}): ${errMsg}`
        );
      }
      return {
        delivered: false,
        errorCode: error.name || "RESEND_ERROR",
        errorMessage: errMsg,
        isTestingRestriction: restricted,
      };
    }

    console.log(`✉️ [EmailService] Sent ${category} email (id: ${data?.id ?? "unknown"})`);
    return {
      delivered: true,
      messageId: data?.id,
    };
  } catch (err: any) {
    console.error(
      `❌ [EmailService] Unexpected error sending ${category} email:`,
      err?.message || err
    );
    return {
      delivered: false,
      errorCode: "RESEND_EXCEPTION",
      errorMessage: err?.message || "Unexpected email delivery error",
    };
  }
}

export const emailService = {
  sendOTPEmail(params: OTPEmailParams): Promise<EmailSendResult> {
    const rendered = buildOTPEmail(params);
    return sendTransactionalEmail(params.to, rendered, "password-reset-otp");
  },

  sendWelcomeEmail(params: WelcomeEmailParams): Promise<EmailSendResult> {
    const rendered = buildWelcomeEmail(params);
    return sendTransactionalEmail(params.to, rendered, "welcome");
  },

  sendAccountCreatedEmail(params: AccountCreatedEmailParams): Promise<EmailSendResult> {
    const rendered = buildAccountCreatedEmail(params);
    return sendTransactionalEmail(params.to, rendered, "account-created");
  },

  sendPasswordChangedEmail(params: PasswordChangedEmailParams): Promise<EmailSendResult> {
    const rendered = buildPasswordChangedEmail(params);
    return sendTransactionalEmail(params.to, rendered, "password-changed");
  },

  sendSecurityNotificationEmail(params: SecurityNotificationParams): Promise<EmailSendResult> {
    const rendered = buildSecurityNotificationEmail(params);
    return sendTransactionalEmail(params.to, rendered, `security-${params.type.toLowerCase()}`);
  },
};

export default emailService;
