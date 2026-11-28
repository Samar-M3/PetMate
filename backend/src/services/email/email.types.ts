export interface EmailSendResult {
  delivered: boolean;
  messageId?: string;
  errorCode?: string;
  errorMessage?: string;
  isTestingRestriction?: boolean;
}

export interface OTPEmailParams {
  to: string;
  displayName?: string | null;
  otp: string;
  expiresInMinutes?: number;
}

export interface WelcomeEmailParams {
  to: string;
  displayName?: string | null;
  createdAt?: Date;
}

export interface AccountCreatedEmailParams {
  to: string;
  displayName?: string | null;
  createdAt?: Date;
}

export interface PasswordChangedEmailParams {
  to: string;
  displayName?: string | null;
  changedAt?: Date;
}

export type SecurityAlertType =
  | "NEW_LOGIN"
  | "SECURITY_ALERT"
  | "EMAIL_CHANGE"
  | "ACCOUNT_DELETION"
  | "ACCOUNT_NOTICE";

export interface SecurityNotificationParams {
  to: string;
  displayName?: string | null;
  type: SecurityAlertType;
  subject: string;
  headline: string;
  message: string;
  occurredAt?: Date;
  actionHint?: string;
}

export interface RenderedEmailContent {
  subject: string;
  html: string;
  text: string;
}
