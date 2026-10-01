// 회귀 테스트 (검증자의 파일 — 수정 금지)
const assert = require("assert");
const { submitOrders } = require("../src/ui");

assert.strictEqual(submitOrders([{ qty: 1 }, { qty: 2 }]), "모든 주문이 접수되었습니다");
assert.strictEqual(submitOrders([{ qty: 1 }, { qty: 0 }]), "1건의 주문이 실패했습니다");
console.log("tests OK");
