import { test, describe } from "node:test";
import assert from "node:assert/strict";
import matchingConfig from "../src/config/matching.config.ts";
import { getSlotPaymentProvider } from "../src/modules/slots/slots.payment.ts";

describe("Slots & Payments Module", () => {
  test("matching config limits slots correctly", () => {
    assert.equal(matchingConfig.MAX_PAID_SLOTS, 5);
    assert.equal(matchingConfig.SLOT_DURATION_DAYS, 30);
    assert.ok(matchingConfig.SLOT_PRICE_NPR > 0);
  });

  test("getSlotPaymentProvider returns provider conforming to SlotPaymentProvider interface", async () => {
    const esewaProvider = getSlotPaymentProvider("esewa");
    assert.equal(esewaProvider.name, "esewa");

    const init = await esewaProvider.initiatePayment({
      paymentId: "test-pay-1",
      amount: 500,
      userId: "user-1",
      description: "Slot purchase",
    });

    assert.equal(init.paymentId, "test-pay-1");
    assert.equal(init.amount, 500);
    assert.ok(init.transactionId.startsWith("txn_"));
    assert.ok(init.paymentUrl.includes("esewa"));

    const verify = await esewaProvider.verifyPayment({
      paymentId: "test-pay-1",
      transactionId: init.transactionId,
    });
    assert.equal(verify.success, true);
    assert.equal(verify.transactionId, init.transactionId);
  });

  test("khalti provider returns khalti initiation url", async () => {
    const khaltiProvider = getSlotPaymentProvider("khalti");
    assert.equal(khaltiProvider.name, "khalti");

    const init = await khaltiProvider.initiatePayment({
      paymentId: "test-pay-2",
      amount: 1000,
      userId: "user-2",
      description: "Khalti slot purchase",
    });

    assert.ok(init.paymentUrl.includes("khalti"));
  });
});
