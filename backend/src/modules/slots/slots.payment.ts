export interface SlotPaymentInitiation {
  paymentId: string;
  gateway: string;
  amount: number;
  transactionId: string;
  paymentUrl: string;
  params: Record<string, any>;
}

export interface SlotPaymentVerificationResult {
  success: boolean;
  transactionId: string;
  amount: number;
  gatewayRaw?: any;
}

export interface SlotPaymentProvider {
  name: string;
  initiatePayment(params: {
    paymentId: string;
    amount: number;
    userId: string;
    description: string;
  }): Promise<SlotPaymentInitiation>;

  verifyPayment(params: {
    paymentId: string;
    transactionId?: string;
    gatewayPayload?: any;
  }): Promise<SlotPaymentVerificationResult>;
}

export class MockOrSandboxGatewayProvider implements SlotPaymentProvider {
  name: string;

  constructor(gatewayName: "esewa" | "fonepay" | "mock" = "esewa") {
    this.name = gatewayName;
  }

  async initiatePayment(params: {
    paymentId: string;
    amount: number;
    userId: string;
    description: string;
  }): Promise<SlotPaymentInitiation> {
    const transactionId = `txn_${params.paymentId}_${Date.now()}`;
    return {
      paymentId: params.paymentId,
      gateway: this.name,
      amount: params.amount,
      transactionId,
      // No external gateway is called until the real payment integration is enabled.
      paymentUrl: `mock://${this.name}/checkout/${params.paymentId}`,
      params: {
        gateway: this.name,
        amount: params.amount,
        transactionId,
        mode: "mock",
      },
    };
  }

  async verifyPayment(params: {
    paymentId: string;
    transactionId?: string;
    gatewayPayload?: any;
  }): Promise<SlotPaymentVerificationResult> {
    // Mock mode intentionally accepts the simulated checkout and lets the API grant the slot.
    return {
      success: true,
      transactionId: params.transactionId || `txn_${params.paymentId}`,
      amount: params.gatewayPayload?.amount || 0,
      gatewayRaw: params.gatewayPayload,
    };
  }
}

export function getSlotPaymentProvider(gatewayName?: string): SlotPaymentProvider {
  const chosen = (gatewayName || process.env.SLOT_PURCHASE_PROVIDER || "esewa").toLowerCase();
  if (chosen !== "esewa" && chosen !== "fonepay") {
    throw new Error("Unsupported slot payment method. Choose eSewa or Fonepay.");
  }
  return new MockOrSandboxGatewayProvider(chosen);
}
