# 연출 점검 (visual-audit) — 2026-10-01

> 입력 = docs/design/v2/09-visual-gui-sound.md B · B-2 · 04-events.md · 08-drop-visuals.md · docs/phase/QUEUE-ALL1-report.md.
> 방법 = 코드 읽기만(roblox/src). **Play 확인 없음 — 캡처 경로 없음.** 코드로 확인 못 한 것은 [추정]. 구현 뒤 Play 캡처는 `Claude outputs/QUEUE-ALL2-B/`에 둔다(예정).

## 1. 목적 · 범위 · 안전 규칙 요약

- 목적: 로직은 있는데 표현이 약한 사건을 찾아 1순위(즉시 효과 큼) · 2순위(적은 비용)만 구현하고, 3순위는 목록으로 남긴다.
- 범위: 전투(타격 · 처치 · 피격) · 보스 · 드랍 · 강화 · 성장(레벨업 · 환생) · 도감 · 전 서버 이벤트(균열 · 합동 목표).
- 안전 규칙(09 B 0~6):
  - 0 이 문서를 먼저 커밋한 뒤 구현한다. 통합 · 삭제는 제안만 하고 실행하지 않는다.
  - 1 폰트 단계 · 중앙 금지 구역(40% × 50%) · ScreenMap · 회피 부등식을 지킨다.
  - 2 플레이어 입력 앞에 준비 동작을 넣지 않는다(전조는 적만).
  - 3 히트스톱 · 흔들림 · 줌 = 클라 로컬, 보스 전조를 가리지 않는다.
  - 4 성능 기준은 필드 12인 · 보스 4인 · 폰이다. 내 효과는 강하게, 남의 효과는 약하게 한다.
  - 5 이미 정한 것은 다시 논의하지 않는다.
  - 6 새 연출은 모두 ArtStyleV1 스위치 뒤에 두고, 끄면 전과 같아야 한다.
- 피로 금지 기준(B-2 · 이것이 우선):
  - 일반 사냥 중 화면 흔들림 0(내 강공격 적중만 아주 약하게).
  - 흔들림/번쩍임은 같은 3초 안에 1번까지.
  - 화면 전체 번쩍임은 클라이맥스만.
  - "연출 세기(끔 · 약 · 보통)" 하나로 흔들림 · 번쩍임 · 남의 효과를 함께 줄인다.

### 1-1. 지금 설정 연결 상태(근거)
| 항목 | 지금 | 근거 |
|---|---|---|
| FxLevel → 옛 속성 | 끔 = 흔들림 끔 + ReduceFlashes 켬 · 약/끔 = 남의 궤적 흐리게 | client/FxSettings.client.lua `apply` |
| FxScale(1 · 0.5 · 0) | **값만 넣고 읽는 코드가 없음**(grep `GetAttribute("FxScale")` 0건) | client/FxSettings.client.lua |
| 흔들림 세기 × FxScale | **없음** — FxSettings 주석에는 "CameraShake가 FxScale 0.5를 곱한다"고 적혀 있지만 CameraShake에 그 코드가 없음 | client/CameraShake.lua `trigger` · `fovKick` |
| "3초에 1번" 제한 | **없음** — 주석이 말하는 `FxBudget` 모듈이 저장소에 없음. CameraShake는 마지막 호출로 덮어쓰기만 함 | client/CameraShake.lua |
| SettingScreenShake | CameraShake.trigger · fovKick · BossIntroCinema가 따름 | client/CameraShake.lua · client/BossIntroCinema.client.lua |
| 설정을 무시하는 흔들림 | 태초/초월 땅울림 `rumble`이 Humanoid.CameraOffset을 직접 흔듦(설정 안 봄) | client/PrimordialFx.client.lua `rumble` |
| ReduceFlashes | ArtV1Fx.screenFlash · ArtV1View(강화 대성공) · PrimordialFx · RiftView · GateWeather · BossBodyFx · BossStormView가 따름 | 각 파일 grep |
| 기존 빈도 제한 | 균열 번개 초당 2.5회 미만(RiftData.maxFlashPerSecond) · 소리 minInterval(SoundData) · 관문 번개 16~32초 간격 | shared/data/RiftData.lua · SoundData.lua · client/GateWeather.client.lua |
| 소리 | 훅만 있고 soundId 14개가 모두 빈 값 = 무음 | client/SoundHooks.client.lua · shared/data/SoundData.lua |

### 1-2. 지금 흔들림 호출 전부(피로 기준 대조)
| 호출 | 세기(초 · stud) | 상황 | B-2 기준 |
|---|---|---|---|
| AttackInput `showResult` 3타 강타 | 0.15 · 0.35 | 일반 사냥 매 콤보 | 강공격 — 허용하되 "아주 약하게"로 낮춤 |
| AttackInput `showResult` 백스텝샷 | 0.1 · 0.2 | 일반 사냥 | **위반**(강공격 아님) |
| SkillInput 광역 `tick` | 0.2 · 0.5 | 채널 틱마다 → 3초 안에 여러 번 | **위반**(가장 셈) |
| SkillVfx greatswordAir · bowFinisher 발사 · 적중 | 0.12 · 0.18~0.28 | 발사 + 적중 = 2번 | 발사 흔들림 **위반** · 적중만 허용 |
| AttackInput 보스 적중 FOV 킥 | 2.5° · 0.1초 | 보스에게 넣는 내 적중마다 | 3초 규칙 **위반** |
| FallFx 넘어짐(나) | 0.35 · 0.8 | 큰 피격 | "큰 전조 공격에 맞음" 범주 — 세기 낮춤 |
| BossFx.shake | 데이터 | 보스 패턴 근처 | 허용(보스 설정 따름) |
| ArtV1View 강화 대성공 · BossIntroCinema · PrimordialFx rumble | 데이터 | 클라이맥스 | 허용 |

## 2. 상위 사건 표(20개)

중요도는 일반 · 중요 · 클라이맥스로 나눈다. 흐름은 입력 → 준비 → 행동 → 충돌/변화 → 결과 → 정착의 여섯 단계이며, ✓는 있음, ✗는 없음, △는 약함을 뜻한다. 정리 등급 1은 즉시 효과가 큰 것, 2는 비용이 적은 것, 3은 나중에 다듬을 것이다.

| 순위 | 사건 | 중요도 | 지금 흐름 | 근거(파일:함수) | 부족한 점 | 제안 | 등급 |
|---|---|---|---|---|---|---|---|
| 1 | 피로 기준 · 연출 세기 통합 | 전체 | — | CameraShake.lua `trigger` · `fovKick` · FxSettings.client.lua `apply` · PrimordialFx `rumble` | FxScale을 아무 코드도 안 읽음. 3초 제한이 없음. 일반 사냥에서 흔들림 3곳이 기준 위반. rumble이 설정 무시 | 흔들림 · 번쩍임 통로 한 곳에 종류(heavy · hurt · boss · climax)와 × FxScale · 3초 쿨(climax 제외)을 넣음. 사냥 흔들림 제거 | 1 |
| 2 | 일반 몹 적중(내 평타 · 스킬) | 일반 | 입력✓ 행동✓ 충돌△ 결과✓ 정착✓ | HitEffects.lua `playHit` · `flashMonster` · DamageNumbers.lua `show` · AttackInput `showResult` | 흰 번쩍 = 즉시 흰색 → 0.15초 복귀(기준 0.06). 텍스처 메시 몸체는 Color만 바꿔서는 안 보일 수 있음[추정]. 밀림 없음(서버가 위치를 덮어쓴다는 주석). 치명 숫자가 일반과 같은 노란색(크기 · 글꼴만 다름). 타격음 무음 | 번쩍 0.06초 유지 + 0.06초 복귀 · 텍스처 몸체면 Highlight 채움 번쩍 · 아트 리그는 루트 관절 Transform으로 0.1초 뒤로 0.3 stud(전조 포즈 중이면 건너뜀) · 치명 숫자 = 금색 + 외곽선 + "!" · 내 숫자 ×1.2 | 1 |
| 3 | 로켓단식 처치(강공격 · 치명 · 넉백 처치) | 중요(클립) | 결과△ | HitEffects.lua `playDeath`(버스트 + 제자리 축소 0.35초) · ArtV1View 쓰러짐 | 강한 마무리도 일반 처치와 모습이 같음 | 내 화면에만 몸을 복제해 날림: 원본은 LocalTransparencyModifier로 숨기고, 복제본을 내 반대쪽 위로 포물선 0.6초 + 회전 + 축소, 꼭대기에서 "반짝" 별빛 0.25초. 드랍 · 판정은 서버 그대로(원래 자리) | 1 |
| 4 | 보스 적중 · 파티원 색 | 중요 | 내 적중✓ 남 적중✗ | AttackServer `attackResult:FireClient`(본인에게만) · server/DamageFeed.lua + DamageFeedView(`DamageNumberData.enabled = false`) · PartyListView(직업색만) | 남이 때린 것이 보이지 않음(궤적 제외). 파티원 색 개념이 없음. 이름표 색은 게임패스 치장이라 겹칠 수 있음 | 파티 슬롯 4색(데이터)을 파티 창 줄 · 이름표 작은 점 · 적중 불꽃 · 숫자에 씀. 내 적중 = 크고 밝게, 남 = ×0.6 · 투명 0.35. 보스 대상만 DamageFeed를 켬 | 1 |
| 5 | 내가 맞음(작은 · 큰 피해) | 일반~중요 | 충돌✓ 결과△ | PlayerHitFeedback.client.lua(머리 위 숫자 + WeaponVisual `playHit` 움찔/밀림) · PlayerDamage.takeDamage → `hitFeedback:FireClient(damage, absorbed)` | 화면 가장자리 신호가 없음. 큰 공격과 작은 공격의 체감 차이가 몸 동작뿐임. 소리 없음 | 가장자리 붉은 번짐: 작은 피해 = 투명 0.8, 0.25초 · 큰 피해(damage ÷ MaxHp ≥ bigHitFraction 0.12) = 투명 0.55, 0.45초 + 흔들림 hurt(0.12초 · 0.15 stud × FxScale) + hurtHeavy 소리 자리 | 1 |
| 6 | 체력 30% 아래 | 중요 | ✗ | PlayerHealthBar.client.lua `updateFillAndLabel`(바 색만) | 위험 상태 신호가 없음 | Hp ÷ MaxHp < 0.3이면 가장자리 심장 박동(주기 1.0초, 투명 0.85↔0.72 × FxScale). ReduceFlashes면 박동 없이 고정 번짐. 가장자리 12%만 | 1 |
| 7 | 22강 이상 → 12강 초기화 | 클라이맥스(클립) | 결과△ | ArtV1View `playFail("down")`(하락과 같은 모습) · panels/Enhance/init.lua `resultLine`(글자 한 줄) | 1~2강 하락과 모습이 같음 | reset 전용: 쇳조각 ×2 · 어두운 링 ×1.5 · 0.4초 채도 −0.5(밝기 변화 없음 = 번쩍임 아님) · 패널 단계 숫자 22→12가 0.8초 동안 굴러 내려감 · 흔들림 없음 | 1 |
| 8 | 초월 세트 줄 완료 | 클라이맥스(클립) | 결과△ | CodexService `refresh` → CodexNotice(`lineDone`) → panels/Codex `Toast.push`(금 글자 4초) | 일반 줄 칭호와 같은 토스트 한 줄. 04 문서의 연쇄(빛기둥 → 배너 → 세트 줄)에 마지막 고리가 없음 | 초월 줄이면 흑금 배너(TranscendentData 색) 6초 + 발밑 흑금 링(ArtV1Fx.ring) · 전 화면 번쩍임 없음 | 1 |
| 9 | 강화 성공 · 대성공 | 클라이맥스 | 입력✓ 행동✓ 결과✓ 정착△ | ArtV1View `playEnhance`(번쩍 · 링 · 불꽃, +5단위 = 빛기둥 · 화면 반짝 · 흔들림) · Enhance `resultLine` | 패널 쪽은 글자 색만 바뀜. 단계 숫자가 튀지 않음 | 패널 단계 숫자 팝(1 → 1.25 → 1, 0.25초 Back) + 결과 줄 0.15초 확대 | 2 |
| 10 | 강화 실패 · 19~21강 하락 | 클라이맥스 | 결과✓ | ArtV1View `playFail`(유지 = 연기 · 하락 = 링 + 연기 + 쇳조각) | 패널 숫자가 즉시 바뀜 | 숫자가 0.4초 동안 내려감 + 결과 줄 좌우 흔들기 0.2초(UI만, 카메라 아님) | 2 |
| 11 | 방지권 발동 | 클라이맥스 | 결과△ | Enhance `resultLine`(`blockedBy` → 흰 글자 "막았습니다") | 막은 순간이 보이지 않고, 흰 글자라 눈에 띄지 않음 | 모루 위 푸른 방패 링(ArtV1Fx.ring, 0.5초) + 결과 줄 success 색 + 남은 장수 숫자 팝 | 2 |
| 12 | 보스 마무리 → 승리 → 보상 | 클라이맥스 | 행동✓ 결과✓ 정착△ | BossAnimator `startDeathClone` · `deathZoom`(FOV × 0.82) · 슬로 0.8초(BossMotionData) · BossLingerClient → panels/BossLinger | 사망 인지 · 여운은 있음. "승리" 마침표 없이 선택 창이 바로 나옴[추정: 창 여는 시각은 서버 신호 기준] | 줌이 끝나는 1.2초에 "처치!" 도장 1.0초(TC 줄 · 보스 강조색) → 그 뒤 잔류 창. 반복 방해가 없도록 1초 이내 | 2 |
| 13 | 레벨업 | 클라이맥스 | 결과✓ 정착△ | ArtV1Dopamine `levelUp`(발밑 링 · 입자) · SystemToasts(important 토스트) · LevelHud(숫자만) · ExpBar | HUD 칩과 경험치바에 반응이 없음 | 레벨 칩 팝 0.3초 + 경험치바가 가득 → 0으로 흰 스윕 0.3초 | 2 |
| 14 | 도감 칸 완료(받기 전) | 중요 | 변화✓ 결과✗ | CodexService `refresh`(`r.done` 기록만, 알림 없음) · 받을 때만 `got` 토스트 | 칸이 차는 순간 반응이 없음(창을 열어야 앎) | 완료 순간 작은 토스트 "도감 칸 완성: 이름"(BC 획득 줄 · 1.6초 · 묶음) + 메뉴 도감 아이콘 점 | 2 |
| 15 | 줄 칭호 | 클라이맥스 | 결과△ | CodexService → CodexNotice `lineDone` → Toast(금 4초) | 토스트 한 줄뿐 | important 등급 토스트 + 발밑 금색 링 1회(ArtV1Fx) | 2 |
| 16 | 장비 줍기 | 일반 | 결과✓ 정착△ | SystemToasts BC 획득 줄(ItemPickedUp) · DropLookV2(착지 통통 · 번쩍) | 땅 모델이 그냥 사라짐. 빨려 드는 느낌이 없음 | 사라지기 직전 드랍 자리 → 내 캐릭터로 작은 빛 구슬 0.3초(등급색 · 영웅 이상) | 2 |
| 17 | 내 체력바 잔상 | 일반 | ✗ | PlayerHealthBar.client.lua(즉시 변경) · 보스바에는 있음(hud/BossBar `lag`) | 큰 피해를 읽기 어려움 | 보스바 lag 방식 그대로: 흰 잔상 바가 0.4초 뒤 따라 줄어듦 | 2 |
| 18 | 합동 목표 단계 달성 | 클라이맥스 | 결과✓ | CommunityGoalView `CommunityGoalBanner` → Toast(금 6초) | 허브 게이지가 차는 움직임이 없음[추정] | 허브 게이지 채움 트윈 0.6초 + 칸 반짝 | 3 |
| 19 | 균열 시작 · 종료 | 클라이맥스 | ✓ | RiftView(하늘 · 날씨 · 번개 · 배너 · 남은 시간) | 번개 초당 2.5회 미만은 B-2의 "3초 1번"보다 잦음(날씨라 예외로 볼지 결정 필요) | 유지. FxLevel 약 = 번개 ×0.5, 끔 = 없음 | 3 |
| 20 | 태초 · 초월 드랍 · 보스 첫 처치 드랍 | 클라이맥스 | ✓ | PrimordialFx(섬광 · 슬로 · 올려다보기 · 갈라짐 · 궤도 · 결정) · DropLightning · DropLookV2 · ArtV1Dopamine | 잘 되어 있음. rumble만 설정 무시(1번에서 해결) | 유지 | — |

참고로 유지(추가 작업 없음)로 본 사건은 다음과 같다.
- 보스 등장: BossIntroCinema(첫 조우 3초 / 짧은 판 1.2초, HUD 숨김) · BossIntroCard가 있다. 잡몹 등장과 확실히 다르다.
- 환생: ArtV1Dopamine `rebirth`(빛기둥 · 링 · 화면 반짝)가 있다.
- 잡몹 전조: MonsterRigAnimator 전조 포즈가 있다.

## 3. 구현 계획

### 3-1. 1순위(B-2 전부 + 클립 2건)

**① 피로 게이트(가장 먼저 — 나머지가 이 통로를 쓴다)**
- 수치 파일: shared/data/VfxData.lua에 `V.fatigue` 표를 추가한다.
  - `cooldownSeconds = 3`
  - `kinds = { heavy = { scale = 0.35 }, hurt = {...}, boss = {...}, climax = { bypassCooldown = true } }`
- 흔들림: client/CameraShake.lua의 `trigger(duration, studs, kind)`에 세 번째 인자를 더한다.
  - 인자가 없으면 옛 동작 그대로.
  - 인자가 있으면 `studs × FxScale × kinds[kind].scale`로 세기를 정하고, climax가 아니면 마지막 흔들림·번쩍임 뒤 3초 안의 호출은 버린다.
  - `fovKick`도 같은 쿨을 따른다.
- 번쩍임: 공유 시각 `lastFlashAt`을 CameraShake 모듈에 두고, ArtV1Fx `screenFlash`가 읽고 쓴다(흔들림과 같은 3초 창). 화면 전체 번쩍임은 climax만.
- 호출부 정리. 판정 코드는 건드리지 않고 연출 호출만 바꾼다.
  - AttackInput `showResult`: 3타 강타 → `"heavy"`, 백스텝샷 흔들림 제거, 보스 FOV 킥 → `"heavy"` 쿨.
  - SkillInput 광역 tick 흔들림 제거.
  - SkillVfx 발사 흔들림 제거, 적중 흔들림 → `"heavy"`.
  - FallFx → `"hurt"`, BossFx.shake → `"boss"`, ArtV1View 대성공 → `"climax"`.
  - PrimordialFx `rumble`: `SettingScreenShake`가 false면 건너뛰고, 세기에 FxScale을 곱한다.
- 확인 방법:
  - Play에서 3타 콤보를 10초 동안 반복하고, 흔들림 로그(Studio 전용 print)가 3초에 1번 이하인지 본다.
  - FxLevel 끔 · 약 · 보통 세 가지에서 흔들림 크기를 비교한다.
  - `git diff -- roblox/src/server` 0줄.

**② 일반 몹 타격감**
- client/HitEffects.lua
  - `flashMonster`: 흰색 유지 0.06초 → 0.06초 복귀(값은 VfxData.mobHit).
  - 몸체가 MeshPart + TextureID/SurfaceAppearance면 Color 대신 OutlinePool 슬롯의 Highlight(FillColor 흰색, FillTransparency 0.35)를 0.06초 붙인다[추정: 텍스처에는 Color가 안 먹는지 Play로 확인].
- client/MonsterRigAnimator.client.lua: 새 함수 `nudge(model, dir)` 조각을 추가한다.
  - 루트 관절 Transform을 0.08초 동안 0.3 stud 뒤로 밀었다가 0.1초에 복귀한다.
  - `MobWindup`이 켜져 있으면 건너뛴다(전조를 가리지 않음).
  - 서버 CFrame은 건드리지 않는다.
- client/DamageNumbers.lua `show`: 치명은 금색(ArtV1FxData.combat.critCore 계열) + 외곽선 + "!", 일반은 옅은 흰색, 크기 ×1.2.
- 히트스톱은 지금 `WeaponVisual.applyHitstop`(내 무기만, 로컬)을 그대로 쓰고, 강공격 · 마무리에만 적용한다. 광역 스킬 틱마다 거는 0.12초는 첫 틱에만 건다.
- 소리: SoundData에 `hitHeavy` 자리(빈 soundId)를 추가한다.
- 설정 연결:
  - FxScale 0이면 링 · 밀림을 끄고 번쩍 · 숫자만 남긴다(정보).
  - ReduceFlashes면 흰 번쩍 대신 밝기 +30%로 한다.

**③ 로켓단식 처치**
- 트리거는 기존 신호만 쓴다(서버 변경 없음): AttackInput `showResult`에서 `died and (isComboHit or isCrit or isFinisher)`, SkillInput `playHits`에서 `hit.isDead and hit.isCrit`, 강궁 넉백(heavyShot) 처치.
- 구현: HitEffects `playDeath(model, opts)`에 `opts.launch` 분기를 추가한다.
  - BossAnimator `startDeathClone`과 같은 방식으로 한다: 복제 → 원본 LocalTransparencyModifier = 1 → 복제본 Anchored.
  - 내 반대 방향 + 위로 포물선을 그린다(0.6초, 높이 18 stud, 회전 720°, 크기 × 0.4).
  - 끝에 ArtV1Fx.flash(작은 별 크기 2, 0.25초, 흰 금색) + 별 입자 4개를 낸다.
- 상한: 동시 2개 · 쿨 0.4초 · 폰 1개(값은 VfxData.launch). 넘으면 옛 사망 연출로 돌린다.
- 판정 불변 확인:
  - 드랍은 서버 ItemDropSpawner가 서버 몸 위치에 만든다. Play에서 처치 직전 서버 Root 위치와 드랍 모델 위치를 비교해 오차 0이어야 한다.
  - `git diff -- roblox/src/server` 0줄.
- 남의 화면에서는 보통 사망 모습이다(attackResult는 본인에게만 감). 그래서 "남 효과 약"을 자동으로 만족한다.
- FxScale 0이면 끄고, 0.5면 높이 × 0.6에 별 없이 한다.

**④ 보스 파티원 색**
- 데이터: shared/data/UIColors.lua에 `partySlot = { 하늘 · 연두 · 보라 · 분홍 }`을 추가한다. 보스 경고색(주황 · 빨강)과 등급색을 피하고, 대비 검사를 거친다.
- 슬롯 = 파티 목록 순서(PartyListView와 같은 순서). 서버 PartyService에 이미 있는 순서를 쓴다[추정: 순서 필드 이름은 확인 필요].
- 서버(연출 방송만): server/DamageFeed.lua를 **보스 대상일 때만** 켠다(DamageNumberData에 `bossOnly = true`). 판정 · 피해 계산은 바꾸지 않는다.
- 클라:
  - DamageFeedView가 남의 적중을 슬롯색 · 작게(others.scale 0.6, 투명 0.35) 그리고 HitEffects 버스트도 같은 색 · 작게 낸다.
  - 내 적중은 DamageNumbers + 내 슬롯색 테두리로 크게 · 밝게 그린다.
  - hud/PartyListView 줄 왼쪽에 슬롯색 막대 4px, Nameplate 이름 옆에 슬롯색 점을 둔다(게임패스 이름표 색은 그대로).
  - 보스 체력바 잔상은 공통(hud/BossBar `lag` 유지).
- 성능: 4인 × 초당 약 3회 = 12개 이하, maxShown 24 풀.

**⑤ 내가 맞을 때 · 체력 30% 아래**
- 새 파일 client/HurtEdge.client.lua 하나(그리기 전용)를 만든다.
  - ScreenGui(IgnoreGuiInset, DisplayOrder는 HUD 아래)에 네 변 Frame + UIGradient 투명도를 쓴다. 화면 폭 · 높이의 12%까지만(중앙 금지 구역 밖).
  - 입력: PlayerHitFeedback을 한 번 더 듣는다(SoundHooks와 같은 방식) + Player 속성 `Hp` · `MaxHp`.
  - 큰 피해 판정 = `(damage + absorbed) / MaxHp ≥ PlayerMotionData.overlay.bigHitFraction`(0.12, 기존 값 재사용). 전조 공격 종류를 따로 보낼지는 2순위로 미룬다.
  - 큰 피해면 `CameraShake.trigger(0.12, 0.15, "hurt")` + `hurtHeavy` 소리 자리.
  - 설정: 번짐 투명도에 `1 − (1 − t) × FxScale`을 쓰고, ReduceFlashes면 박동 없이 고정한다.
- 수치: shared/data/VfxData.lua `V.hurtEdge`.

**⑥ 22강 초기화 · ⑦ 초월 세트 줄**
- ⑥ ArtV1View `playFail`에 reset 종류를 추가한다(ArtV1FxData.enhanceFail.reset). panels/Enhance/init.lua에서 결과가 reset이면 단계 숫자 굴림 트윈을 건다.
- ⑦ CodexService가 줄 완료 때 보내는 CodexNotice에 두 번째 인자 `kind = "trans"`를 붙인다(연출 신호만). panels/Codex에서 흑금 배너 + ArtV1Fx.ring을 낸다.

### 3-2. 2순위(적은 비용 · 각 30~60줄)
- 강화 성공 숫자 팝 · 실패 숫자 굴림 · 방지권 방패 링: panels/Enhance/init.lua `connectResult` 콜백 + ArtV1View.
- 보스 처치 도장 "처치!": 새 파일 없이 BossLingerClient가 창을 열기 전에 Toast TC(1.0초)를 띄운다. 창은 0.6초 늦게 연다(클라에서만. 서버 남은 초는 그대로).
- 레벨업 HUD 팝: LevelHud 칩 UIScale 트윈 + ExpBar 흰 스윕.
- 도감 칸 완료 알림: CodexService `refresh`에서 새로 `done`이 된 칸을 모아 CodexNotice 한 번(묶음) → BC 줄.
- 줄 칭호: Toast important + 발밑 금 링.
- 줍기 빛 구슬: SystemToasts의 ItemPickedUp을 다시 듣는다. 드랍 모델이 사라진 자리 → 내 캐릭터로 0.3초(영웅 이상, FxScale 따름)[추정: 줍기 신호에 위치가 없으면 가장 가까운 드랍 모델 위치를 기억해 둠].
- 내 체력바 잔상: PlayerHealthBar에 lag 바(hud/BossBar와 같은 lagSeconds).
- 큰 피해 종류 신호: PlayerDamage.takeDamage `hitFeedback:FireClient`에 3번째 인자 `heavy`(opts.label이 보스 패턴이면 true)를 붙인다. 연출 신호만 추가하므로 판정 코드는 손대지 않는다.

## 4. 3순위(목록만)
- 버튼 누름 크기 변화(ui/kit/Button 눌림 = 색만 → UIScale 0.95)
- 스킬 쿨 끝 반짝
- 합동 목표 허브 게이지 채움 트윈
- 균열 번개 FxLevel 연동
- 잡몹 사망 조각 흩어짐(비 아트 몸체)
- 골드 팝업 숫자 올라감
- 펫 부화 카메라
- 초월 오라 남의 화면 세기
- 드랍 이름표 겹침 재점검
- 소리 음원 채우기(09 C 절)

## 5. 유지 · 통합 · 삭제 제안(실행 금지)
- 유지: BossIntroCinema · BossIntroCard · PrimordialFx 전체 · DropLookV2 · DropLightning · ArtV1Dopamine 환생 · RiftView · 보스바 잔상.
- 통합:
  - 흔들림 경로 3개(CameraShake.trigger · BossIntroCinema 자체 흔들림 · PrimordialFx `rumble`의 CameraOffset)를 CameraShake 한 통로로 모은다.
  - 피해 숫자 두 벌(DamageNumbers · DamageFeedView)은 U1에서 하나로 모은다(DamageNumberData 주석대로).
- 삭제 후보:
  - 백스텝샷 흔들림(AttackInput `BUFFED_CAMERA_SHAKE_*`)
  - 광역 스킬 틱 흔들림(SkillInput `E_CAMERA_SHAKE_*`)
  - 활 발사 흔들림(VfxData.bowFinisher.shake)
  - FxSettings.client.lua의 틀린 주석(FxBudget · FxScale 곱)
- 확인 필요: 보스 적중 FOV 킥(A2-N3 결정 ①)은 3초 규칙과 부딪힌다. 쿨로 줄일지, 끌지 사용자가 판단해야 한다.
- 규칙 메모: AttackInput · SkillInput에 히트스톱 · 흔들림 수치가 하드코딩되어 있다(`HEAVY_HITSTOP_SECONDS` 등). 게이트 작업 때 VfxData로 옮기기를 제안한다.

## 6. 점검 질문 답(09 B)
| 질문 | 답 |
|---|---|
| 입력 직후 시각 · 청각 · 햅틱 | 시각: 공격 궤적 · 버튼 눌림색 있음. 청각: 무음(SoundData 빈 값). 햅틱: 코드에 HapticService 0건 |
| 폰 햅틱 동작 여부 | HapticService는 게임패드 진동이 기본이다(`IsVibrationSupported(Enum.UserInputType.Gamepad1)`). 휴대폰 터치 진동 지원은 제한적이다[추정: 대상 폰에서 `IsVibrationSupported(Enum.UserInputType.Touch)`를 Play로 먼저 확인]. 확인 전에는 제안하지 않는다 |
| Tween · Easing | UI · 연출 대부분 Quad Out, 치명 숫자만 Back Out. 강화 · 레벨 숫자 Tween 없음(2순위) |
| 준비 · 찌그러짐 · 여운 · 2차 움직임 | 적 전조 포즈(MonsterRigAnimator) · 보스 스프링 있음. 플레이어 입력 준비 없음(규칙 2 준수) |
| 히트스톱 · 번쩍임 · 넉백 · 흔들림 | 히트스톱 = 내 무기 로컬(WeaponVisual.applyHitstop). 몹 번쩍 0.15초(길다). 몹 넉백 표현 없음. 흔들림 기준 위반 3곳(1-2) |
| 입자 · 궤적 · 충격 · 잔상 | 궤적(AttackTrail) · 타격 링(ArtV1) · 스킬 충격(SkillVfx) 있음 |
| 피해 미리보기 · 늦게 줄어드는 체력바 · 숫자 올라감 | 보스바 잔상만 있음. 내 체력바 잔상 · 숫자 올라감 없음 |
| 카메라 | 보스 등장 · 사망 줌 · 태초 올려다보기 · 초월 궤도 있음(로컬) |
| 등장 · 획득 · 레벨업 · 사망 · 퇴장 | 보스 등장 강함. 획득(줍기) 약함. 레벨업 HUD 반응 없음. 잡몹 사망은 축소뿐 |
| 결과 화면 · 승리 · 게임 오버 | 보스 승리 = 잔류 선택 창(마침표 없음). 사망 = SoulView[추정] |
| 버튼 상태 | ui/kit/Button: 기본 · 눌림 · 비활성 · 처리 중 있음. 크기 변화 없음 |
| 정보 위계 · 가독성 | 치명 숫자 색이 일반과 같음. 남의 피해 숫자 없음(보스에서 누가 때렸는지 모름) |
| 등장 · 퇴장 타이밍 | 토스트 = Toast 등급 규칙. 강화 결과 줄 = 즉시 교체 |
| 소리 · 화면 동기화 | 훅 위치는 맞음(AttackResult · EnhanceResult 등). 음원 없음 |
| 반복 시 지루하게 긴 연출 | 보스 첫 조우 3초 · 이후 1.2초로 이미 줄임. 강화 대성공 1.4초는 +5 단위만이라 적정 |
| 같은 정보 중복 · 시선 방해 | 내 피격 = 머리 위 숫자 + 체력바. 가장자리 번짐을 넣으면 3중이 되므로 작은 피해의 숫자는 흐리게 할지 Play로 판단 |
| 보스 판정 크기 vs 모션 · 궤적 | QUEUE-ALL1 보고서 §7에서 맞춤(평타 +0.03초 · 원 안 반경 12) |
| 균열 날씨가 전조 · 드랍 빛 · 이름표를 가리는지 | 아레나 안개 상한 0.45 · 전조는 날씨 위(RiftData 주석). 드랍 빛 가림은 미확인[추정] — 캡처 필요 |
| 중요도 비례 세기 | 지금은 일반 사냥(3타 · 광역 틱)이 클라이맥스(강화 대성공 0.12 stud)보다 더 세게 흔들림 → 뒤집혀 있음. ①로 해결 |
