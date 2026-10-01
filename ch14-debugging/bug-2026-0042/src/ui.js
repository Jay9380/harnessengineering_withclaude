// 프런트 쪽 흉내: 주문 결과 배너 문구를 만든다.
const { createOrders } = require("./orders");

function submitOrders(items) {
  const res = createOrders(items);
  const failed = res.body.failedIndices.length;
  return failed === 0 ? "모든 주문이 접수되었습니다" : `${failed}건의 주문이 실패했습니다`;
}

module.exports = { submitOrders };
