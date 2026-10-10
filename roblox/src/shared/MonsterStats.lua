-- QUEUE-N1004 C-4(D11 기반): 몬스터 · 보스의 체력 · 공격 · 방어를 계산하는 한 곳. 서버 스폰 · 피해 판정(MonsterState) · 보스 인스턴스(BossRules) ·
--   몹 정보 UI(TargetFocus 대상 줄) · 시뮬(EconSim · BalanceSim)이 모두 이 모듈을 읽는다(같은 지점 = 같은 값 - 하네스 monster_stats_test가 30지점 이상 오차 0으로 고정).
--   식 자체는 InfiniteStage(스테이지 배율 · 구간 배율)와 BossCurveData(보스 공격 완화) 그대로 - 이 모듈은 조립만 한다(값 불변 통합).
--   방어: 지금 몹 방어 개념이 없어 필드 자리만(MonsterData 항목의 defense - 없으면 0 · 아직 어떤 피해 식도 읽지 않는다 = 동작 변화 없음). ALL10-P2가 재조정 · 돌파 계수를 여기에 붙인다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local BossCurveData = require(ReplicatedStorage.Shared.data.BossCurveData)
local All10 = require(ReplicatedStorage.Shared.All10) -- QUEUE-ALL10 2-6 몹 곡선(전역 재조정 · 사람별 돌파 계수 - 스위치 끔 = 1)
local ReferenceBuild = require(ReplicatedStorage.Shared.ReferenceBuild) -- PROG-2B-1 몹 기준 함수(새 힘만큼 HP 계수)

local MonsterStats = {}

-- 잡몹(구간 배율 포함). base = MonsterData tier 표(hp · attack · defense?) · prefix = 접두사 표(hpMultiplier) 또는 nil
-- QUEUE-ALL10 2-6(D3 · D11): 전역 재조정 = All10.hpCurveFactor · attackCurveFactor(16,000부터) - 스위치 끄면 1이라 지금 곡선(골든 표 그대로).
-- PROG-2B-1: × ReferenceBuild.hpFactor(기준 빌드 한 대 기대 피해 비 - 잡몹 · 보스 같은 계수)
function MonsterStats.trashHp(baseHp, stage)
	return InfiniteStage.getTrashHp(baseHp, stage) * All10.hpCurveFactor(stage) * ReferenceBuild.hpFactor(stage)
end

function MonsterStats.trashAttack(baseAttack, stage)
	return InfiniteStage.getTrashAttack(baseAttack, stage) * All10.attackCurveFactor(stage)
end

-- 사람별 돌파 계수(계승한 사람에게만 · 몹 HP에 곱하는 값): 서버는 그 사람이 주는 피해 ÷ 이 값(MonsterState - 레벨차 계수와 같은 자리) · 몹 정보 UI는 HP × 이 값 · EconSim도 같은 함수.
function MonsterStats.breakFactor(stage, inheritStage)
	return All10.breakFactor(stage, inheritStage)
end

function MonsterStats.defense(base)
	return type(base) == "table" and tonumber(base.defense) or 0
end

-- inheritStage(선택 · QUEUE-ALL10) = 보는 사람의 계승 스테이지 → 그 사람 기준 HP(돌파 계수)
function MonsterStats.trash(base, stage, prefix, inheritStage)
	return {
		hp = MonsterStats.trashHp(base.hp, stage) * (prefix and prefix.hpMultiplier or 1) * MonsterStats.breakFactor(stage, inheritStage),
		attack = MonsterStats.trashAttack(base.attack, stage),
		defense = MonsterStats.defense(base),
	}
end

-- 보스(구간 배율 없음 · tier 압축 전 HP). BossRules.buildInstanceDataFrom이 부른다 - 인원 배수(partyHpMultiplier)는 BossRules가 계산해 넘긴다.
function MonsterStats.bossHp(trashBase, stage, boss, hpMultiplierExtra, partyHpMultiplier)
	return InfiniteStage.getMonsterHp(trashBase.hpUnscaled or trashBase.hp, stage) * boss.hpMultiplier * hpMultiplierExtra * partyHpMultiplier * All10.hpCurveFactor(stage) * ReferenceBuild.hpFactor(stage)
end

function MonsterStats.bossAttack(trashBase, stage, boss)
	return InfiniteStage.getMonsterAttack(trashBase.attack, stage) * boss.attackMultiplier * InfiniteStage.interpBand(BossCurveData.attackEase, stage) * All10.attackCurveFactor(stage)
end

return MonsterStats
