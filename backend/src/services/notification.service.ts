import prisma from "../config/db.ts";
import { messaging as defaultMessaging } from "../config/firebase.ts";
import type { MulticastMessage } from "firebase-admin/messaging";

let currentMessaging: any = defaultMessaging;

export function setMessagingForTesting(mock: any) {
  currentMessaging = mock;
}

export type NotificationCategory =
  | "messages"
  | "requests"
  | "matches"
  | "orders"
  | "system";

export type LocalizedText = string | { en: string; ne?: string };

export interface SendNotificationOptions {
  category: NotificationCategory;
  type: string;
  title: LocalizedText;
  body: LocalizedText;
  data?: Record<string, string | number | boolean | null | undefined>;
  collapseKey?: string;
}

export interface RegisterDeviceTokenInput {
  token: string;
  platform?: string;
  appVersion?: string;
  locale?: string;
}

export interface UpdatePreferencesInput {
  messages?: boolean;
  requests?: boolean;
  matches?: boolean;
  orders?: boolean;
  system?: boolean;
  showPreviews?: boolean;
}

const INVALID_TOKEN_ERROR_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

export function resolveLocalizedText(text: LocalizedText, locale: string = "en"): string {
  if (typeof text === "string") return text;
  if (locale === "ne" && text.ne) return text.ne;
  return text.en;
}

export function getChannelIdForCategory(category: NotificationCategory): string {
  switch (category) {
    case "messages":
      return "messages";
    case "requests":
    case "matches":
      return "requests_matches";
    case "orders":
      return "orders";
    case "system":
    default:
      return "system";
  }
}

export class NotificationService {
  /**
   * Registers or updates a device token. Reassigns to current user if held by someone else.
   * Keeps at most 10 tokens per user, pruning the oldest.
   */
  static async registerDeviceToken(
    userId: string,
    input: RegisterDeviceTokenInput
  ) {
    const trimmedToken = input.token.trim();
    if (!trimmedToken) {
      throw new Error("Token cannot be empty");
    }

    const platform = (input.platform || "android").toLowerCase();
    const locale = (input.locale || "en").toLowerCase() === "ne" ? "ne" : "en";

    // Upsert token by unique token string (reassigns if held by another user)
    const deviceToken = await prisma.deviceToken.upsert({
      where: { token: trimmedToken },
      update: {
        userId,
        platform,
        appVersion: input.appVersion ?? null,
        locale,
        lastSeenAt: new Date(),
      },
      create: {
        userId,
        token: trimmedToken,
        platform,
        appVersion: input.appVersion ?? null,
        locale,
      },
    });

    // Prune tokens if user has more than 10
    const tokens = await prisma.deviceToken.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      select: { id: true },
    });

    if (tokens.length > 10) {
      const idsToDelete = tokens.slice(10).map((t) => t.id);
      await prisma.deviceToken.deleteMany({
        where: { id: { in: idsToDelete } },
      });
    }

    return deviceToken;
  }

  /**
   * Removes a device token for the current user.
   */
  static async removeDeviceToken(userId: string, token: string): Promise<number> {
    const trimmedToken = token.trim();
    const result = await prisma.deviceToken.deleteMany({
      where: {
        userId,
        token: trimmedToken,
      },
    });
    return result.count;
  }

  /**
   * Retrieves notification preferences for a user, or defaults if not yet set.
   */
  static async getPreferences(userId: string) {
    const pref = await prisma.notificationPreference.findUnique({
      where: { userId },
    });

    if (!pref) {
      return {
        userId,
        messages: true,
        requests: true,
        matches: true,
        orders: true,
        system: true,
        showPreviews: true,
      };
    }

    return pref;
  }

  /**
   * Updates notification preferences for a user.
   */
  static async updatePreferences(
    userId: string,
    updates: UpdatePreferencesInput
  ) {
    return prisma.notificationPreference.upsert({
      where: { userId },
      update: updates,
      create: {
        userId,
        messages: updates.messages ?? true,
        requests: updates.requests ?? true,
        matches: updates.matches ?? true,
        orders: updates.orders ?? true,
        system: updates.system ?? true,
        showPreviews: updates.showPreviews ?? true,
      },
    });
  }

  /**
   * Sends a push notification to a user across all their registered device tokens.
   * - Skips suspended or inactive users.
   * - Skips if category is disabled in user preferences.
   * - Respects showPreviews for chat messages.
   * - Formats localized text per token locale.
   * - Prunes invalid / unregistered tokens.
   * - Never logs tokens or message contents.
   */
  static async sendToUser(
    userId: string,
    options: SendNotificationOptions
  ): Promise<{ sent: boolean; successCount: number; failureCount: number }> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        notificationPreference: true,
        deviceTokens: true,
      },
    });

    if (!user || !user.isActive) {
      return { sent: false, successCount: 0, failureCount: 0 };
    }

    // Check category preferences
    const pref = user.notificationPreference;
    if (pref) {
      if (options.category === "messages" && !pref.messages) return { sent: false, successCount: 0, failureCount: 0 };
      if (options.category === "requests" && !pref.requests) return { sent: false, successCount: 0, failureCount: 0 };
      if (options.category === "matches" && !pref.matches) return { sent: false, successCount: 0, failureCount: 0 };
      if (options.category === "orders" && !pref.orders) return { sent: false, successCount: 0, failureCount: 0 };
      if (options.category === "system" && !pref.system) return { sent: false, successCount: 0, failureCount: 0 };
    }

    const tokens = user.deviceTokens;
    if (!tokens || tokens.length === 0) {
      return { sent: false, successCount: 0, failureCount: 0 };
    }

    // Determine body with showPreviews check
    let resolvedBodyTemplate: LocalizedText = options.body;
    if (options.category === "messages" && pref?.showPreviews === false) {
      resolvedBodyTemplate = {
        en: "New message",
        ne: "नयाँ सन्देश",
      };
    }

    // Ensure all data values are strings
    const stringData: Record<string, string> = {
      category: options.category,
      type: options.type,
    };
    if (options.data) {
      for (const [key, value] of Object.entries(options.data)) {
        if (value !== undefined && value !== null) {
          stringData[key] = String(value);
        }
      }
    }

    const channelId = getChannelIdForCategory(options.category);
    const isChat = options.category === "messages";

    // Group device tokens by locale so title/body match the device language
    const tokensByLocale = new Map<string, string[]>();
    for (const dt of tokens) {
      const loc = dt.locale === "ne" ? "ne" : "en";
      const list = tokensByLocale.get(loc) || [];
      list.push(dt.token);
      tokensByLocale.set(loc, list);
    }

    let totalSuccess = 0;
    let totalFailure = 0;
    const tokensToDelete: string[] = [];

    for (const [locale, tokenList] of tokensByLocale.entries()) {
      const localizedTitle = resolveLocalizedText(options.title, locale);
      const localizedBody = resolveLocalizedText(resolvedBodyTemplate, locale);

      const message: MulticastMessage = {
        tokens: tokenList,
        notification: {
          title: localizedTitle,
          body: localizedBody,
        },
        data: stringData,
        android: {
          priority: isChat ? "high" : "normal",
          notification: {
            channelId,
            tag: options.collapseKey,
            priority: isChat ? "high" : "default",
            defaultSound: true,
          },
        },
      };

      try {
        const response = await currentMessaging.sendEachForMulticast(message);
        totalSuccess += response.successCount;
        totalFailure += response.failureCount;

        if (response.failureCount > 0) {
          response.responses.forEach((resp: any, idx: number) => {
            if (!resp.success && resp.error) {
              const errCode = resp.error.code || "";
              console.warn(`[NotificationService] FCM failure error code: ${errCode}`);
              if (INVALID_TOKEN_ERROR_CODES.has(errCode)) {
                tokensToDelete.push(tokenList[idx]!);
              }
            }
          });
        }
      } catch (err: any) {
        console.error(`[NotificationService] Multicast batch failure error code: ${err.code || err.message}`);
        totalFailure += tokenList.length;
      }
    }

    // Clean up stale or unregistered tokens from DB
    if (tokensToDelete.length > 0) {
      await prisma.deviceToken.deleteMany({
        where: { token: { in: tokensToDelete } },
      });
      console.log(`[NotificationService] Pruned ${tokensToDelete.length} invalid tokens for user ${userId}`);
    }

    console.log(
      `[NotificationService] Sent push to user ${userId} (${options.category}): ${totalSuccess} succeeded, ${totalFailure} failed`
    );

    return {
      sent: true,
      successCount: totalSuccess,
      failureCount: totalFailure,
    };
  }

  /**
   * Hook for role application status changes (SELLER / VETERINARIAN).
   */
  static async notifyApplicationStatus(
    userId: string,
    applicationType: string,
    approved: boolean
  ) {
    const roleTitle = applicationType === "SELLER" ? "Seller" : "Veterinarian";
    const title = approved
      ? { en: `${roleTitle} Application Approved! 🎉`, ne: `${roleTitle} आवेदन स्वीकृत भयो! 🎉` }
      : { en: `${roleTitle} Application Update`, ne: `${roleTitle} आवेदनको जानकारी` };
    const body = approved
      ? {
          en: `Congratulations! Your application to become a ${roleTitle} has been approved.`,
          ne: `बधाई छ! तपाईंको ${roleTitle} बन्ने आवेदन स्वीकृत भएको छ।`,
        }
      : {
          en: `Your application to become a ${roleTitle} was not approved at this time.`,
          ne: `तपाईंको ${roleTitle} आवेदन यस पटक स्वीकृत हुन सकेन।`,
        };

    return NotificationService.sendToUser(userId, {
      category: "system",
      type: "application_status",
      title,
      body,
      data: {
        route: applicationType === "SELLER" ? "/seller" : "/vet",
        applicationType,
        status: approved ? "APPROVED" : "REJECTED",
      },
      collapseKey: `app_${applicationType.toLowerCase()}`,
    });
  }

  /**
   * Hook for order status changes.
   */
  static async notifyOrderStatus(
    userId: string,
    orderId: string,
    orderNumber: string,
    status: string
  ) {
    return NotificationService.sendToUser(userId, {
      category: "orders",
      type: "order_status",
      title: {
        en: `Order ${orderNumber} Update`,
        ne: `अर्डर ${orderNumber} को स्थिति`,
      },
      body: {
        en: `Your order status is now: ${status}`,
        ne: `तपाईंको अर्डर स्थिति अब: ${status}`,
      },
      data: {
        route: `/shop/orders/${orderId}`,
        orderId,
        orderNumber,
        status,
      },
      collapseKey: `order_${orderId}`,
    });
  }

  /**
   * Hook for appointment changes.
   */
  static async notifyAppointmentStatus(
    userId: string,
    appointmentId: string,
    status: string,
    vetName?: string
  ) {
    return NotificationService.sendToUser(userId, {
      category: "system",
      type: "appointment_status",
      title: {
        en: "Appointment Update 🩺",
        ne: "भेटघाटको जानकारी 🩺",
      },
      body: {
        en: `Your appointment with ${vetName || "the vet"} is ${status.toLowerCase()}.`,
        ne: `तपाईंको डाक्टरसँगको भेटघाट ${status.toLowerCase()} भएको छ।`,
      },
      data: {
        route: `/appointments/${appointmentId}`,
        appointmentId,
        status,
      },
      collapseKey: `apt_${appointmentId}`,
    });
  }

  /**
   * Hook for event reminders.
   */
  static async notifyEventReminder(
    userId: string,
    eventId: string,
    eventTitle: string
  ) {
    return NotificationService.sendToUser(userId, {
      category: "system",
      type: "event_reminder",
      title: {
        en: "Upcoming Pet Event Reminder 🎈",
        ne: "आगामी कार्यक्रमको सम्झना 🎈",
      },
      body: {
        en: `Don't forget! "${eventTitle}" is coming up soon.`,
        ne: `नबिर्सनुहोला! "${eventTitle}" छिट्टै हुँदैछ।`,
      },
      data: {
        route: `/events/${eventId}`,
        eventId,
      },
      collapseKey: `event_${eventId}`,
    });
  }
}
