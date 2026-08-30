# 프로젝트 개요

탑다운 2D 강화 웹게임. Canvas 2D로 렌더링하며 프레임워크 없이 순수 HTML + CSS + JavaScript로 작성한다.

# 규칙

- 밸런스 수치는 data/ 폴더 안에만 둔다. core/ 하드코딩 금지
- 새 직업·스킬·몬스터는 데이터 객체 추가로만 구현한다
- 스킬은 effects 배열의 조각 조합으로 정의한다. 스킬 전용 함수를 새로 만들지 않는다
- 저장 구조 변경 시 SAVE_VERSION을 올리고 migrate()에 처리를 추가한다
- 한 번에 한 단계씩만 구현한다. 다음 단계 전에 동작을 확인한다
- 그리기는 render.js에만 둔다. 도형을 이미지로 교체할 때 한 곳만 고치기 위함
- 작업을 마치고 커밋한 뒤에는 origin master로 푸시한다. 푸시해야 GitHub Pages에 반영되어 실제 플레이어가 볼 수 있다.
- PRD 등 문서만 고치는 작업은 브라우저 검증과 문서 전체 재독을 생략한다. 수정한 절의 정합성 확인·수치 대조·헤더 구조(번호 중복·누락) 확인·git diff로 코드 파일이 안 바뀐 것 확인까지만 한다. 단, 파일 분할·이동·대량 재배치처럼 내용이 손실될 수 있는 작업은 예외로 두고 전체를 대조한다.
- 브라우저 검증 중 코드를 고치고 재확인할 때는 navigate가 아니라 하드 리로드(Ctrl+Shift+R)를 쓴다 — `python -m http.server`는 캐시 헤더를 안 보내서 Chrome이 이전 파일을 계속 서빙한다.
- 사용자에게 주는 모든 설명·보고·표·근거 서술은 한국어로 쓴다. 코드 식별자, 파일 경로, 함수명, 변수명, 커밋 메시지, 로그 출력은 원문 그대로 둔다. 영어로 답변하지 않는다. 표의 헤더와 셀 내용도 한국어로 쓴다.
- 로블록스 Studio MCP의 스크립트 편집 기능은 쓰지 않는다. 코드는 항상 roblox/src/ 아래 파일로만 쓰고 Rojo가 Studio에 반영한다. Studio 안에서 스크립트를 고치면 파일과 어긋나고 git diff로 변경을 확인할 수 없게 된다.
- 로블록스 Studio MCP는 읽기·실행·검증 전용으로 쓴다: 플레이테스트 제어, 콘솔 출력 읽기, 화면 캡처, 데이터 모델 탐색, 에셋 삽입.
- 로블록스 각 단계 검증은 사용자에게 스크린샷을 요청하지 말고 Studio MCP로 직접 플레이테스트해서 확인한다. 다만 "이게 재미있어 보이는가" 같은 체감 판단은 여전히 사용자에게 묻는다.
- "재현은 되는데 원인이 코드 밖 같다" 싶을 때, 그럴듯한 설명에서 조사를 멈추지 마라. 결론 내리기 전에 실제 인스턴스(Studio에서 GetDescendants 등으로 직접 탐색)나 실제 코드를 한 번 훑는다. 이 프로젝트에서 같은 실수가 반복됐다 — 웹 툴팁 버그를 "8px 간격 때문"이라 결론 냈다가 진짜 원인(hover 우선순위)이 나중에 나왔고, 로블록스 부활 스폰 버그도 "Studio Play Here 특성"이라 결론 냈다가 실제로는 원점에 남아있던 기본 SpawnLocation이 원인이었다(두 세션을 잘못된 전제 위에서 보냄).

# Behavioral Guidelines

Behavioral guidelines to reduce common LLM coding mistakes.
Scope: Only what current models still get wrong. If the model or the harness already handles something reliably, it doesn't belong here — a rule that restates default behavior burns context and buys nothing.
Tradeoff: These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. State Assumptions, Then Proceed
Say what you assumed. Keep going. Default the rest.
Before implementing:
- State your assumptions in one line, then start.
- If multiple interpretations exist, pick the likeliest and say which one you picked.
- If a simpler approach exists, say so while doing the work — not as a question that blocks it.
- Ask only when the answer changes what gets built, not how well, and the wrong choice can't be cheaply undone.

A stated assumption gets corrected in seconds. A question costs a round-trip and hands the work back to the user. If you're about to ask a second question in one task, you're doing it wrong.

## 2. Simplicity First
Minimum code that solves the problem. Nothing speculative.
- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes
Touch only what you must. Clean up only your own mess.
When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Verify Before Done
If you touched code, run the check before saying "done" — and report what actually ran.
- `npm test`, `pytest`, `cargo test`, whatever the project uses. Smallest relevant check first, broader checks when risk is high.
- No test setup? At minimum, verify the project builds or typechecks.
- Report the exact command and its result: "passed", "failed with X", or "not run because Y".
- Never write "done", "fixed", or "works" unless a concrete check backs it.
- Run it proactively, before the user signals "끝", "완료", "다 됐어".

For this project: verify by running the local server and checking actual behavior in the browser.

This is the step LLMs skip most often. Treat it as non-negotiable.

## 5. Teach One Thing On The Way Out
End with what the user would want to know next time. Two or three sentences.
When the work is done:
- Name the one concept, tradeoff, or gotcha that actually mattered here.
- Teach what the code doesn't show: why this way over the obvious one, which default you leaned on, what breaks first at scale.
- If it needs a heading, it's too long. If it restates the diff, delete it.
- Skip it when the change is trivial, or when the user is the one who taught you the thing.

Why: an agent that only ships code leaves the user unable to maintain it. They should finish each task slightly more able to do it without you.

These guidelines are working if: fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and stated assumptions get corrected early instead of surfacing as mistakes late.
