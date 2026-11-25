import { test, describe } from "node:test";
import assert from "node:assert/strict";
import matchingConfig from "../src/config/matching.config.ts";
import { getSlotPaymentProvider } from "../src/modules/slots/slots.payment.ts";

describe("Slots & Payments Module", () => {
  test("matching config limits slots correctly", () => {
    assert.equal(matchingConfig.MAX_PAID_SLOTS, 1);
    assert.equal(matchingConfig.SLOT_DURATION_DAYS, 30);
    assert.equal(matchingConfig.SLOT_PRICE_NPR, 100);
  });

  test("getSlotPaymentProvider returns provider conforming to SlotPaymentProvider interface", async () => {
    const esewaProvider = getSlotPaymentProvider("esewa");
    assert.equal(esewaProvider.name, "esewa");

    const init = await esewaProvider.initiatePayment({
      paymentId: "test-pay-1",
      amount: 100,
      userId: "user-1",
      description: "Slot purchase",
    });

    assert.equal(init.paymentId, "test-pay-1");
    assert.equal(init.amount, 100);
    assert.ok(init.transactionId.startsWith("txn_"));
    assert.ok(init.paymentUrl.startsWith("mock://esewa/"));
    assert.equal(init.params.mode, "mock");

    const verify = await esewaProvider.verifyPayment({
      paymentId: "test-pay-1",
      transactionId: init.transactionId,
    });
    assert.equal(verify.success, true);
    assert.equal(verify.transactionId, init.transactionId);
  });

  test("fonepay provider returns a mocked payment initialization", async () => {
    const fonepayProvider = getSlotPaymentProvider("fonepay");
    assert.equal(fonepayProvider.name, "fonepay");

    const init = await fonepayProvider.initiatePayment({
      paymentId: "test-pay-2",
      amount: 100,
      userId: "user-2",
      description: "Fonepay slot purchase",
    });

    assert.ok(init.paymentUrl.startsWith("mock://fonepay/"));
    const verify = await fonepayProvider.verifyPayment({
      paymentId: "test-pay-2",
      transactionId: init.transactionId,
    });
    assert.equal(verify.success, true);
  });
});
