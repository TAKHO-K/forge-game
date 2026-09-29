# A2-N1 상태 파일 (끊기면 여기서 재개)

## 진행 요약 (폰 확인용 3줄)
1. 갈래 = **렌더만**(ROBLOX_ASSETS_KEY 없음) · 허용 목록 적용 · 시험 통과(2026-09-30 06:10).
2. ★1 대검 8등급 **완료**(8.0) · 2 쌍검 · 활 · 지팡이 × 일반 · 전설 · 초월 **완료**(8.2 / 8.0 / 8.0 · 도형 대비 확실히 나음).
3. 다음 = 3 몬스터 T1 ~ T3(`make_monsters.py` 작성함).

> 지시 = A2-N1 이어서 + 확장(시간 제한 없음 · 작업 목록 끝 또는 사용량 한도까지). 설계서 = `docs/art/asset-design-n1.md`.
> 도구: `roblox/tools/blender/artlib.py`(공용) · `make_weapons.py`(무기) · `render_blend.py`(이전 .blend 비교 렌더) · `compose.py` · `sheets.py`(모음 - 라벨은 메타에서) · 실행기 `bash roblox/tools/blender/bl.sh <스크립트> <인자>`.
> 렌더 PNG = `Claude outputs/ART-night/`(커밋 안 함 - 기존 관례) · 메시 = `roblox/art/<종류>/`(fbx · blend · meta 커밋).
> 옛 A2-S2 대검 원본 = `git show 0ae0380:roblox/art/weapons/greatsword.blend`(비교 렌더 = `Claude outputs/ART-night/greatsword/old/`).
> 재개 순서: git pull → 이 파일 → 아래 "다음 할 일".

## 진행

| 단계 · 에셋 | 상태 | 삼각형 | 점수 | 이전 대비 | 메모 |
|---|---|---|---|---|---|
| 1단계 설계서 · 라이브러리 | 완료 | - | - | - | 936cd59 |
| 1 대검 8등급 사다리 | 완료 | 450 / 582 / 586 / 610 / 618 / 702 / 783 / 792 | 8.0(검토 6.8 → 7.6 → 자체 8.0) | 확실히 나음 | 수정 2회: 넓은 쐐기 날 · 한쪽 배 · 초월 균열 관통 · 날개 폭 · 전설 가드 ×1.6 · 유물 = 날 가시 2쌍(누적) · 초월 조각 3개 크게 · 손잡이 반경 0.22 · 세부도 등급별(일반 · 희귀 날 10점 단면) |
| 2 쌍검 · 활 · 지팡이 × 일반 · 전설 · 초월 | 완료 | 쌍검 406 / 428 / 422 · 활 432 / 528 / 486 · 지팡이 398 / 482 / 464 | 쌍검 8.2 · 활 8.0 · 지팡이 8.0(검토 7.8 / 6.2 / 6.8 → 수정 1회) | 확실히 나음(3종 - 이전 = WeaponModelData 치수 재현 도형) | 활 전설 화살받이 판 · 큰 보석 · 캡 / 초월 조각 크게 + 균열 폭 0.14(활 2줄) / 지팡이 자루 반경 0.17 ~ 0.25 · 머리 ×1.25 · 구슬 0.42 / 활 String = 렌더 전용(게임은 코드 시위) · 쌍검 = 한 자루 모델을 두 조각에 공용 |

## 다음 할 일
- 3번: `bash roblox/tools/blender/bl.sh roblox/tools/blender/make_monsters.py --species <종> --render "Claude outputs/ART-night/monsters" --old` → 도형 리그와 비교 → 검토 → 커밋.
