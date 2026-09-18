-- 꽂히는 화살(20-5 [2]) 서버 권위 상태 - 속사 중 명중한 평타가 대상 몸에 남겼다가
-- 개별적으로 터지는 화살들의 타이머·상한·정리를 관리한다. 계수·지연·상한은
-- SkillData.bow.Q의 stuckArrow* 필드(단일 출처)를 그대로 읽는다 - 여기 박지 않는다.
--
-- 순환 require를 피하려고 일부러 MonsterSpawner를 require하지 않는다(MonsterSpawner가
-- 이 모듈을 다시 require하는 구조를 만들지 않기 위함 - CombatResolution도 마찬가지 이유로
-- 이 모듈을 모른다). 대신 각 화살은 자기 몫을 다 쓰면(터지든 취소되든) 스스로 목록에서
-- 빠진다 - 몬스터가 죽어도 별도 "정리 호출"을 받지 않고, 나중에 타이머가 실행될 때
-- MonsterState.getData가 nil을 돌려주는 것으로 조용히 무해하게 끝난다(아래 explode 참고).
-- 그래서 "몬스터가 죽으면 정리"는 명시적 배선이 필요 없다 - 시간이 지나면 저절로 비워진다.
--
-- 플레이어 퇴장·직업 변경(지시 - "유령 상태가 생긴 적이 있다")만은 시간이 저절로
-- 해결해주지 않으므로(대상 몬스터가 안 죽으면 화살이 계속 남는다) AttackServer의
-- PlayerRemoving과 ClassServer의 전환 지점에서 이 모듈의 clearForPlayer를 명시적으로
-- 불러야 한다 - BuffState.clearAll과 같은 자리, 같은 이유.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local MonsterState = require(script.Parent.MonsterState)
local CombatResolution = require(script.Parent.CombatResolution)

-- 화살이 꽂히는 순간(클라이언트가 이 시점에 몸에 박힌 Part를 만든다) - 데미지와
-- 무관한 순수 시각 신호라 attach() 안에서 즉시 쏜다(폭발 결과를 기다리지 않는다).
local stuckArrowAttach = Instance.new("RemoteEvent")
stuckArrowAttach.Name = "StuckArrowAttach"
stuckArrowAttach.Parent = ReplicatedStorage

local stuckArrowResult = Instance.new("RemoteEvent")
stuckArrowResult.Name = "StuckArrowResult"
stuckArrowResult.Parent = ReplicatedStorage

local stuckArrowClear = Instance.new("RemoteEvent")
stuckArrowClear.Name = "StuckArrowClear"
stuckArrowClear.Parent = ReplicatedStorage

local StuckArrowState = {}

-- [Model] = { record, record, ... } (오래된 것이 앞) - 하나의 화살은
-- { id, player, model, base(atk×coefficient, 이미 계산됨), classId, attackerStage, exploded }.
local arrowsByModel = {}
local nextId = 0

-- [Player] = os.clock() (clearForPlayer가 마지막으로 불린 시각) - 실기 검증 중 발견한
-- 경합: 평타를 "쏜" 시점(AttackServer가 wasQuickShotActive를 스냅샷하는 시점)과 그
-- 평타가 실제로 "명중"해 attach()가 불리는 시점(releaseDelay+travelTime 뒤) 사이에
-- 플레이어가 퇴장하거나 직업을 바꾸면, clearForPlayer는 그 순간 존재하지도 않았던
-- 화살을 지울 수 없다 - 스위치 직후에 뒤늦게 유령 화살이 하나 더 꽂히는 사고가
-- 재현됐다(대검으로 바꾼 직후 화살 1개가 새로 붙는 것을 실측으로 확인). attach()가
-- 요청 시점 타임스탬프를 받아 그 시점이 clearedAt보다 이르면(=이미 지나간 요청이면)
-- 조용히 무시한다.
local clearedAt = {}

local function removeFromList(model, record)
	local list = arrowsByModel[model]
	if not list then
		return
	end
	for i, r in ipairs(list) do
		if r == record then
			table.remove(list, i)
			break
		end
	end
	if #list == 0 then
		arrowsByModel[model] = nil -- 목록이 비면 테이블 자체를 지운다(죽은 몬스터 모델을 계속 들고 있지 않는다).
	end
end

-- 데미지를 적용하고 결과를 쏘는 실제 폭발. 자연 지연(task.delay)이든 상한 초과로 인한
-- 조기 폭발이든 이 함수 하나를 공유한다 - exploded 플래그로 중복 실행을 막는다
-- (MonsterState.tryClaimDeath와 같은 "check-and-set 사이에 yield 없음" 원칙).
local function explode(record)
	if record.exploded then
		return
	end
	record.exploded = true
	removeFromList(record.model, record)

	local model = record.model
	-- 몬스터가 이미 죽었거나(despawn이 MonsterState.clear를 이미 불렀다) 사라졌으면
	-- 조용히 끝난다 - 데미지도 이펙트도 없다("몬스터가 먼저 죽으면 꽂힌 화살은 그냥
	-- 사라진다", 지시).
	if not (model.Parent and MonsterState.getData(model)) then
		return
	end

	local damage, isCrit = PlayerCombat.calcDamage(record.base, record.classId)
	local isDead, dealt = MonsterState.applyDamage(model, damage, record.attackerStage, record.player)
	damage = dealt -- 29-1: 실제로 들어간 피해(보스 파훼 게이트 반영)

	stuckArrowResult:FireClient(record.player, model, record.id, damage, isCrit, isDead)
	CombatResolution.resolveHit(record.player, model, isDead)
end

-- 취소 - 데미지 없이 조용히 지운다(플레이어 퇴장·직업 변경 전용, explode와 분리해서
-- "터졌다"는 클라이언트 이펙트가 절대 같이 나가지 않게 한다).
local function cancel(record)
	if record.exploded then
		return
	end
	record.exploded = true
	removeFromList(record.model, record)
end

-- 속사 버프 중 명중한 평타 하나가 이 화살을 남긴다(AttackServer.server.lua 호출).
-- atk·classId·attackerStage는 이 타격 시점의 스냅샷 - 나중에 터질 때 그 사이 장비가
-- 바뀌어도 이 화살이 처음 꽂혔을 때의 공격력 기준을 그대로 쓴다(평타 하나하나가
-- 독립적으로 계산되는 기존 원칙과 같다). hitDirection(Vector3, 단위벡터)은 시각 효과가
-- "날아온 방향으로 꽂히게" 하는 데만 쓰인다(클라이언트에 그대로 전달). requestedAt은
-- AttackServer가 이 평타를 "쏜" 시점(wasQuickShotActive 스냅샷과 같은 시점)에 찍은
-- os.clock() - clearForPlayer가 그 뒤에 불렸으면 이 화살은 이미 지나간 요청이라 무시한다
-- (위 clearedAt 주석 참고).
function StuckArrowState.attach(model, player, atk, classId, attackerStage, hitDirection, requestedAt)
	if requestedAt and clearedAt[player] and requestedAt < clearedAt[player] then
		return nil
	end

	local def = SkillData.bow.Q

	-- 상한 초과 - 가장 오래된 것(맨 앞)부터 즉시 터뜨린다("상한을 넘으면 가장 오래된
	-- 것부터 터진다", 지시). 피해 손실은 없다 - 예정보다 일찍 터질 뿐이다. explode가
	-- removeFromList를 거쳐 목록이 0개가 되면 arrowsByModel[model] 자체를 지우므로,
	-- 아래에서 새로 넣기 전에 반드시 다시 조회/생성한다(지운 직후의 낡은 테이블
	-- 참조에 넣으면 arrowsByModel과 연결이 끊긴 유령 목록이 생긴다).
	while true do
		local list = arrowsByModel[model]
		if not list or #list < def.stuckArrowMaxPerMonster then
			break
		end
		explode(list[1])
	end

	local list = arrowsByModel[model]
	if not list then
		list = {}
		arrowsByModel[model] = list
	end

	nextId += 1
	local record = {
		id = nextId,
		player = player,
		model = model,
		base = atk * def.stuckArrowDamageCoefficient,
		classId = classId,
		attackerStage = attackerStage,
		exploded = false,
	}
	table.insert(list, record)

	stuckArrowAttach:FireClient(player, model, record.id, hitDirection)

	task.delay(def.stuckArrowDelaySeconds, function()
		explode(record)
	end)

	return record.id
end

-- 플레이어 퇴장·직업 변경(BuffState.clearAll과 같은 자리) - 그 플레이어가 꽂아 둔 화살을
-- 전부 데미지 없이 지우고, 클라이언트에 시각 정리를 알린다(모델이 안 죽어도 남을 수
-- 있으므로 - 몬스터 사망과 달리 모델 자체가 사라지지 않아 자동 정리에 기대지 못한다).
function StuckArrowState.clearForPlayer(player)
	clearedAt[player] = os.clock()
	for model, list in pairs(arrowsByModel) do
		-- 뒤에서부터 지운다 - cancel이 list에서 항목을 remove하며 인덱스를 당기므로
		-- 앞에서부터 돌면 건너뛰는 항목이 생긴다.
		for i = #list, 1, -1 do
			local record = list[i]
			if record.player == player then
				cancel(record)
			end
		end
	end
	stuckArrowClear:FireClient(player)
end

return StuckArrowState
