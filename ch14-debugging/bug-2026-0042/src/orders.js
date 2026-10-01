// 주문 API (서버 쪽 흉내). 주문 생성은 비동기 작업으로 처리되고 즉시 202와 jobId만 돌려준다.
const jobs = new Map();
let seq = 0;

function createOrders(items) {
  const jobId = `job-${++seq}`;
  // 실제로는 큐에서 처리된다. 여기서는 즉시 계산해 두되, 결과는 getJob으로만 조회할 수 있다.
  const failedIndices = items.flatMap((it, i) => (it.qty > 0 ? [] : [i]));
  jobs.set(jobId, { status: "done", failedIndices });
  return { status: 202, body: { jobId, status: "processing" } };
}

function getJob(jobId) {
  return jobs.get(jobId) ?? { status: "unknown" };
}

module.exports = { createOrders, getJob };
