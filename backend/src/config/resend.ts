import { Resend } from "resend";
import env from "./env.ts";

let resendClient: Resend | null = null;

export const isResendConfigured = (): boolean => {
  const key = env.RESEND_API_KEY;
  return Boolean(key && key.length > 0 && !key.includes("your_api_key"));
};

export const getResendClient = (): Resend | null => {
  if (!isResendConfigured()) {
    return null;
  }
  if (!resendClient) {
    resendClient = new Resend(env.RESEND_API_KEY);
  }
  return resendClient;
};

export const getDefaultFromAddress = (): string => {
  const name = env.RESEND_FROM_NAME.replace(/[<>"]/g, "").trim() || "PetMate";
  const email = env.RESEND_FROM_EMAIL.trim() || "onboarding@resend.dev";
  return `${name} <${email}>`;
};
