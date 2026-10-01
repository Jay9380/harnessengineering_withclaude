# 버그 리포트 2026-0042
주문 화면에서 간헐적으로 "Cannot read properties of undefined (reading 'length')" (data.failedIndices is undefined) 크래시.
프런트 팀: "서버 응답이 이상하다" / 백엔드 팀: "스테이징에서는 재현되지 않는다".
재현 스크립트: ./reproduction.sh  (수정 전 exit 1, 수정 후 exit 0 이어야 함)
