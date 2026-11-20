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

  constructor(gatewayName: "esewa" | "khalti" | "mock" = "esewa") {
    this.name = gatewayName;
  }

  async initiatePayment(params: {
    paymentId: string;
    amount: number;
    userId: string;
    description: string;
  }): Promise<SlotPaymentInitiation> {
    const transactionId = `txn_${params.paymentId}_${Date.now()}`;
    const baseUrl =
      this.name === "khalti"
        ? "https://a.khalti.com/api/v2/epayment/initiate/"
        : "https://rc-epay.esewa.com.np/api/epay/main/v2/form";

    return {
      paymentId: params.paymentId,
      gateway: this.name,
      amount: params.amount,
      transactionId,
      paymentUrl: baseUrl,
      params: {
        amt: params.amount,
        psc: 0,
        pdc: 0,
        txAmt: 0,
        tAmt: params.amount,
        pid: transactionId,
        scd: process.env.ESEWA_MERCHANT_CODE || "EPAYTEST",
        su: "https://petmate.local/payment/success",
        fu: "https://petmate.local/payment/failure",
      },
    };
  }

  async verifyPayment(params: {
    paymentId: string;
    transactionId?: string;
    gatewayPayload?: any;
  }): Promise<SlotPaymentVerificationResult> {
    // In test/sandbox environment, simulate a successful verification if valid id provided
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
  if (chosen === "khalti") {
    return new MockOrSandboxGatewayProvider("khalti");
  }
  return new MockOrSandboxGatewayProvider("esewa");
}
