# Sans Fishing

멀티플레이어 수집형 낚시 게임 — Roblox Studio / Luau

누적 방문자 **14만 명**, 동접 최대 **100명** 달성.

---

## 게임 소개

낚시대를 업그레이드하며 희귀한 물고기를 수집하고 도감을 채워가는 멀티플레이어 낚시 게임입니다.  
슬라이더 기반 낚시 미니게임, 날씨 변이 시스템, 트랩 자동 수집, 스킬트리, 리더보드 등 다양한 시스템을 포함합니다.

## 플레이 링크

🎮 [Roblox에서 플레이]([https://www.roblox.com/games/your-game-id](https://www.roblox.com/games/129796299052709/Sans-Fishing))

---

## 주요 기능

| 시스템 | 설명 |
|---|---|
| 낚시 미니게임 | 슬라이더+히트존 기반, 등급별 난이도 차등 |
| 날씨 변이 | 비·눈·축제 날씨마다 물고기 가격/상태 변화 |
| 트랩 시스템 | 오프라인 중에도 물고기 자동 축적, 재접속 유도 |
| 스킬트리 | 코인/낚시포인트 두 재화 기반 10종 스킬 |
| 찌(Bobber) 시스템 | 회전 상점 + Robux 전용 찌, 각종 효과 부여 |
| 리더보드 | 코인·도네이션·플레이타임 3종 |
| 데이터 저장 | ProfileService 기반 역할별 DataStore 분리 |

## 기술 스택

- **언어**: Luau
- **엔진**: Roblox Studio
- **동기화**: Rojo (`default.project.json`)
- **데이터**: ProfileService (세션 잠금, Reconcile)
- **네트워크**: RemoteEvent / RemoteFunction / MessagingService (크로스서버)

## 개발 정보

- 개발 기간: 1주 (초기) + 약 3개월 업데이트
- 개발 인원: 2명 (프로그래밍·UI·이팩트 1명, 3D 모델러 1명)
- 담당: 전체 프로그래밍, UI, 이팩트

## 저작권

이 저장소의 소스 코드와 리소스는 저작권법의 보호를 받습니다.  
별도 라이센스가 명시되지 않은 경우 **무단 복제, 배포, 상업적 이용을 금지합니다.**

© 2024–2025 서재민. All rights reserved.  
See [LICENSE](LICENSE) for details.
