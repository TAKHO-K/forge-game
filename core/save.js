// 저장 슬롯 (PRD 9.1-1 단순화 - 슬롯 1개, 테스트 가능한 최소 저장)
const SAVE_VERSION = 3;
const SAVE_KEY = "forge-game-save";

// currentStageIndex처럼 재생성 가능한 값(monsters)과 equipBonuses·weaponExpLevel처럼
// 다른 값에서 매 프레임/로드 시 재계산되는 파생값은 여기 넣지 않는다.
function buildSaveData(state) {
  return {
    version: SAVE_VERSION,
    classId: state.selectedClass.id,
    gold: state.gold,
    weaponLevel: state.weaponLevel,
    weaponExp: state.weaponExp,
    equipment: state.equipment,
    bag: state.bag,
    probabilityTicketCounts: state.probabilityTicketCounts,
    guaranteedTickets: state.guaranteedTickets,
    currentStageIndex: state.currentStageIndex,
    currentBossStageIndex: state.currentBossStageIndex,
    bossTimeRemaining: state.bossTimeRemaining,
    bossRetryCount: state.bossRetryCount,
    autoEnhanceEnabled: state.autoEnhanceEnabled,
    gameSpeed: state.gameSpeed
  };
}

function saveGame(state) {
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(buildSaveData(state)));
  } catch (e) {
    // localStorage 용량 초과·접근 불가 등 - 저장 실패는 게임 진행에 지장 없이 조용히 무시
  }
}

// 버전 마이그레이션 - data.version < SAVE_VERSION일 때 순차 변환.
// 다음 필드 추가 절차: 1) buildSaveData와 main.js의 적용/수집 로직에 필드 추가
// 2) SAVE_VERSION을 올린다 3) 아래에 `if (data.version < N) { ...구버전 보정...; data.version = N; }` 블록 추가
function migrate(data) {
  if (data.version < 2) {
    // 장비 강화(7.5) 도입 - equipment/bag의 기존 아이템에는 enhanceLevel이 없었으므로 0으로 채운다
    if (data.equipment) {
      for (const part of ITEM_PARTS) {
        if (data.equipment[part]) data.equipment[part].enhanceLevel = data.equipment[part].enhanceLevel || 0;
      }
    }
    if (Array.isArray(data.bag)) {
      for (const item of data.bag) {
        if (item) item.enhanceLevel = item.enhanceLevel || 0;
      }
    }
    data.version = 2;
  }
  if (data.version < 3) {
    // 장비 강화(7.5) 폐지 -> 아이템 레벨 각인으로 대체. enhanceLevel을 버리고 itemLevel을 채운다.
    // 획득 시점을 알 수 없으므로 "지금까지 이만큼은 파밍했다"고 보고 저장된 weaponExp로 역산한
    // 현재 캐릭터 레벨을 넣는다 - 1로 채우면 기존에 모은 장비가 전부 최약체로 주저앉아 migrate()의
    // 취지(기존 저장 무손실 승계)에 반하고, 등급별 역산 추정은 이 단계에서 과설계다(설계 승인).
    const migratedLevel = getWeaponLevelFromExp(data.weaponExp);
    if (data.equipment) {
      for (const part of ITEM_PARTS) {
        const item = data.equipment[part];
        if (item) {
          delete item.enhanceLevel;
          item.itemLevel = migratedLevel;
        }
      }
    }
    if (Array.isArray(data.bag)) {
      for (const item of data.bag) {
        if (item) {
          delete item.enhanceLevel;
          item.itemLevel = migratedLevel;
        }
      }
    }
    data.version = 3;
  }
  return data;
}

// 저장 데이터가 게임에 바로 쓸 수 있는 최소 형태인지 검증 - 하나라도 어긋나면 깨진 저장으로 취급.
// bag은 길이를 요구하지 않는다 - 가방 칸 수가 바뀐 뒤의 구버전 저장도 유효한 것으로 보고,
// 실제 길이 보정은 main.js가 로드 시점에 BALANCE.inventoryBagSize 기준으로 한다.
// gameSpeed는 여기 필수 필드로 넣지 않는다 - 없으면(구버전 저장) main.js가 로드 시 기본값 1로
// 떨어뜨리면 충분해서 SAVE_VERSION을 올리거나 migrate()를 쓸 이유가 없다.
function isValidSaveData(data) {
  return !!data && typeof data === "object" &&
    typeof data.version === "number" &&
    !!CLASSES[data.classId] &&
    typeof data.gold === "number" &&
    typeof data.weaponLevel === "number" &&
    typeof data.weaponExp === "number" &&
    !!data.equipment && typeof data.equipment === "object" &&
    Array.isArray(data.bag) &&
    !!data.probabilityTicketCounts && typeof data.probabilityTicketCounts === "object" &&
    Array.isArray(data.guaranteedTickets) &&
    typeof data.currentStageIndex === "number" &&
    typeof data.currentBossStageIndex === "number" &&
    typeof data.bossTimeRemaining === "number" &&
    typeof data.bossRetryCount === "number" &&
    typeof data.autoEnhanceEnabled === "boolean";
}

// 저장을 읽어 검증까지 마친 데이터를 돌려준다.
// 저장이 없으면 null(정상, 최초 실행). 파싱 실패·미래 버전·필드 이상이면 { corrupted: true } -
// 호출부가 흰 화면 대신 새 게임으로 떨어뜨리고 안내 문구를 띄우게 한다.
function loadGame() {
  let raw;
  try {
    raw = localStorage.getItem(SAVE_KEY);
  } catch (e) {
    return null;
  }
  if (!raw) return null;

  let data;
  try {
    data = JSON.parse(raw);
  } catch (e) {
    return { corrupted: true };
  }

  if (typeof data.version !== "number" || data.version > SAVE_VERSION) {
    return { corrupted: true };
  }
  data = migrate(data);
  if (!isValidSaveData(data)) {
    return { corrupted: true };
  }
  return data;
}

function clearSave() {
  try {
    localStorage.removeItem(SAVE_KEY);
  } catch (e) {}
}
