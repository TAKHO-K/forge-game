// 화면 그리기
// 사냥터 영역 배경 - 던전(stageBackground)이 주어지면 세로 그라데이션으로 던전별 색조를 표현 (PRD 8.0)
function drawMapFloor(ctx, mapWidth, mapHeight, wallThickness, forgeHeight, stageBackground) {
  const innerX = wallThickness;
  const innerY = wallThickness;
  const innerW = mapWidth - wallThickness * 2;
  const innerH = mapHeight - wallThickness * 2;
  const groundY = innerY + forgeHeight;
  const groundH = innerH - forgeHeight;

  if (stageBackground) {
    const grad = ctx.createLinearGradient(0, groundY, 0, groundY + groundH);
    grad.addColorStop(0, stageBackground.top);
    grad.addColorStop(1, stageBackground.bottom);
    ctx.fillStyle = grad;
  } else {
    ctx.fillStyle = "#2a2a2a";
  }
  ctx.fillRect(innerX, groundY, innerW, groundH);

  ctx.fillStyle = "#3d3a5c";
  ctx.fillRect(innerX, innerY, innerW, forgeHeight);

  ctx.strokeStyle = "#8877cc";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(innerX, groundY);
  ctx.lineTo(innerX + innerW, groundY);
  ctx.stroke();
}

function drawMapWalls(ctx, mapWidth, mapHeight, wallThickness) {
  ctx.fillStyle = "#555555";
  ctx.fillRect(0, 0, mapWidth, wallThickness);
  ctx.fillRect(0, mapHeight - wallThickness, mapWidth, wallThickness);
  ctx.fillRect(0, 0, wallThickness, mapHeight);
  ctx.fillRect(mapWidth - wallThickness, 0, wallThickness, mapHeight);
}

function drawPlayer(ctx, player, alpha) {
  ctx.globalAlpha = alpha === undefined ? 1 : alpha;

  ctx.fillStyle = "#4da6ff";
  ctx.beginPath();
  ctx.arc(player.x, player.y, player.radius, 0, Math.PI * 2);
  ctx.fill();

  const lineLength = player.radius + 15;
  ctx.strokeStyle = "#ffffff";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(player.x, player.y);
  ctx.lineTo(
    player.x + Math.cos(player.angle) * lineLength,
    player.y + Math.sin(player.angle) * lineLength
  );
  ctx.stroke();

  ctx.globalAlpha = 1;
}

// 쌍검 Q 분신 (도발원) - 플레이어와 구분되도록 반투명 보라색, 남은 시간 비례로 옅어진다
function drawDecoy(ctx, taunt) {
  if (!taunt) return;
  ctx.globalAlpha = Math.min(1, taunt.timer / 1) * 0.6 + 0.15;
  ctx.fillStyle = "#a64dff";
  ctx.beginPath();
  ctx.arc(taunt.x, taunt.y, taunt.radius, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "#e0b3ff";
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.globalAlpha = 1;
}

// 하단 HUD 공통 레이아웃 - 경험치 바(전체 폭) 위에 스탯 패널(좌)·체력(중앙)·스킬+대시(우)가
// 한 줄로 나란히 놓인다. 좌표를 한 곳에서만 정해 그리기와 겹침 확인(장비창·강화 패널)이
// 같은 수치를 쓰게 한다. 장비창(getInventoryLayout)이 화면 중앙에 세로로 고정 폭(470)을
// 차지하므로, 이 band는 그 아래(canvas.height/2 + 235)에 완전히 들어가야 겹치지 않는다 -
// bandTop이 항상 그보다 아래가 되도록 아래 budget을 720p 기준으로 여유 있게 잡았다.
function getHudBottomLayout(ctx) {
  const w = ctx.canvas.width;
  const h = ctx.canvas.height;
  const sideMargin = 14;

  const expBar = { x: sideMargin, y: h - 24, w: w - sideMargin * 2, h: 18 };

  const bandGap = 8;
  const bandHeight = 64;
  const bandBottom = expBar.y - bandGap;
  const bandTop = bandBottom - bandHeight;

  const statPanel = { x: sideMargin, y: bandTop, w: 210, h: bandHeight };

  // 칸 그리드는 maxHp를 알아야 계산되므로(줄바꿈), 여기선 중심 x·바닥 y만 고정하고
  // 실제 칸 배치는 drawPlayerHealthBar가 매 프레임 maxHp 기준으로 계산한다
  const hpBar = { centerX: w / 2, bottomY: bandBottom };

  // 스킬(Q)+대시 - 모바일 대응 시 오른손 엄지 영역이 될 자리라 조작 요소를 여기 모은다
  const clusterW = 110;
  const qIconSize = 44;
  const dashBarW = 100, dashBarH = 10;
  const clusterCenterX = w - sideMargin - clusterW / 2;
  const cluster = {
    x: w - sideMargin - clusterW, y: bandTop, w: clusterW, h: bandHeight,
    qIcon: { x: clusterCenterX - qIconSize / 2, y: bandTop, w: qIconSize, h: qIconSize },
    dashBar: { x: clusterCenterX - dashBarW / 2, y: bandTop + qIconSize + 6, w: dashBarW, h: dashBarH }
  };

  return { expBar, statPanel, hpBar, cluster, bandTop, bandBottom };
}

// 마인크래프트 하트처럼 한 줄에 maxPerRow칸까지 채우고 넘치면 윗줄로 쌓는다 -
// 아랫줄부터 꽉 채우고 맨 위 줄만 나머지 칸수로 남는 방식(인덱스가 클수록 위쪽 줄)
function drawPlayerHealthBar(ctx, layout, hp, maxHp, gameTime) {
  const { centerX, bottomY } = layout.hpBar;
  const slotW = 32, slotH = 24, gap = 5;
  const maxPerRow = BALANCE.hpBarMaxPerRow;
  const rowWidth = maxPerRow * slotW + (maxPerRow - 1) * gap;
  const leftX = centerX - rowWidth / 2;

  const isLow = hp <= 3;
  const blinkOn = Math.floor(gameTime * 4) % 2 === 0;

  for (let i = 0; i < maxHp; i++) {
    const row = Math.floor(i / maxPerRow);
    const col = i % maxPerRow;
    const x = leftX + col * (slotW + gap);
    const y = bottomY - slotH - row * (slotH + gap);

    ctx.fillStyle = i < hp ? "#e05c5c" : "#333333";
    ctx.fillRect(x, y, slotW, slotH);

    ctx.lineWidth = isLow && blinkOn ? 3 : 1;
    ctx.strokeStyle = isLow && blinkOn ? "#ff0000" : "#000000";
    ctx.strokeRect(x, y, slotW, slotH);
  }
}

function drawDashCooldown(ctx, layout, cooldownTimer, cooldownMax) {
  const { x, y, w: width, h: height } = layout.cluster.dashBar;
  const ratio = Math.max(0, Math.min(1, 1 - cooldownTimer / cooldownMax));

  ctx.fillStyle = "#333333";
  ctx.fillRect(x, y, width, height);
  ctx.fillStyle = cooldownTimer <= 0 ? "#4da6ff" : "#888888";
  ctx.fillRect(x, y, width * ratio, height);
  ctx.strokeStyle = "#000000";
  ctx.lineWidth = 1;
  ctx.strokeRect(x, y, width, height);

  ctx.fillStyle = "#ffffff";
  ctx.font = "12px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillText(cooldownTimer <= 0 ? "대시 준비" : `대시 ${cooldownTimer.toFixed(1)}s`, x + width / 2, y + height + 3);
}

// Q 스킬 아이콘 - 쿨다운 중엔 위에서 아래로 줄어드는 반투명 오버레이 + 남은 초, 준비되면 "준비"
function drawSkillCooldown(ctx, layout, skillName, cooldownTimer, cooldownMax) {
  const { x, y, w: size } = layout.cluster.qIcon;
  const ready = cooldownTimer <= 0;
  const ratio = cooldownMax > 0 ? Math.max(0, Math.min(1, cooldownTimer / cooldownMax)) : 0;

  ctx.fillStyle = "#222222";
  ctx.fillRect(x, y, size, size);
  ctx.strokeStyle = ready ? "#4dd97e" : "#666666";
  ctx.lineWidth = 2;
  ctx.strokeRect(x, y, size, size);

  if (!ready) {
    ctx.fillStyle = "rgba(0,0,0,0.6)";
    ctx.fillRect(x, y, size, size * ratio);
  }

  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillStyle = "#ffe066";
  ctx.font = "bold 11px sans-serif";
  ctx.fillText("Q", x + size / 2, y + 3);

  ctx.font = "bold 13px sans-serif";
  ctx.fillStyle = ready ? "#4dd97e" : "#ffffff";
  ctx.fillText(ready ? "준비" : cooldownTimer.toFixed(1), x + size / 2, y + 20);
}

// 캐릭터 스탯 패널 (좌하단) - 흩어져 있던 공격력·방어력·이동속도·치명타율·치명타피해를 한곳에 모음
function drawPlayerStatsPanel(ctx, layout, stats) {
  const { x, y, w, h } = layout.statPanel;
  ctx.fillStyle = "rgba(0,0,0,0.55)";
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = "#555555";
  ctx.lineWidth = 1;
  ctx.strokeRect(x, y, w, h);

  const padding = 8;
  const rowH = (h - padding * 2) / 3;
  const col1X = x + padding;
  const col2X = x + w / 2;
  const rows = [
    [`공격력 ${formatAbbreviatedNumber(stats.attack)}`, `치명타율 ${stats.critRate}%`],
    [`방어력 ${formatAbbreviatedNumber(stats.defense)}`, `치명타피해 ${stats.critDmg}%`],
    [`이동속도 ${stats.speed}`, ""]
  ];

  ctx.font = "12px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  ctx.fillStyle = "#ffffff";
  rows.forEach((row, i) => {
    const ty = y + padding + i * rowH;
    ctx.fillText(row[0], col1X, ty);
    if (row[1]) ctx.fillText(row[1], col2X, ty);
  });
}

function drawProjectiles(ctx, projectiles) {
  ctx.fillStyle = "#ffe066";
  for (const p of projectiles) {
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
    ctx.fill();
  }
}

// 쌍검 좌우 번갈아 공격 색상 - 0=중앙(대검), 1=오른쪽, -1=왼쪽
const MELEE_SWING_SIDE_COLORS = { 0: "#e0e0e0", 1: "#8fd6ff", "-1": "#ffb37d" };

// 대검·쌍검 근접 스윙 이펙트 (PRD 4.1) - 전방 부채꼴 판정 범위를 그대로 시각화, ratio(1→0)에 따라 페이드아웃
// side로 좌/우/중앙 색을 구분, scale(3타 강타 시 > 1)로 이펙트만 확대 - 실제 판정 range는 영향 없음
function drawMeleeSwing(ctx, player, angle, range, arcDegrees, ratio, side, scale) {
  const halfArc = (arcDegrees * Math.PI / 180) / 2;
  const drawRange = range * (scale || 1);
  const peakAlpha = scale && scale > 1 ? 0.65 : 0.5;
  ctx.save();
  ctx.globalAlpha = Math.max(0, ratio) * peakAlpha;
  ctx.fillStyle = MELEE_SWING_SIDE_COLORS[side] || MELEE_SWING_SIDE_COLORS[0];
  ctx.beginPath();
  ctx.moveTo(player.x, player.y);
  ctx.arc(player.x, player.y, drawRange, angle - halfArc, angle + halfArc);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

// 근접 판정 범위 상시 표시 (요구사항 6) - 공격하지 않을 때도 옅게 항상 보여 사거리를 가늠할 수 있게
function drawMeleeRangeIndicator(ctx, player, range, arcDegrees, alpha) {
  const halfArc = (arcDegrees * Math.PI / 180) / 2;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.fillStyle = "#ffffff";
  ctx.beginPath();
  ctx.moveTo(player.x, player.y);
  ctx.arc(player.x, player.y, range, player.angle - halfArc, player.angle + halfArc);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function drawMonster(ctx, monster, gameTime) {
  if (!monster.alive) return;

  if (monster.rareType === "sparkle") {
    const hue = (gameTime * 180) % 360;
    ctx.save();
    ctx.shadowColor = `hsl(${hue}, 100%, 60%)`;
    ctx.shadowBlur = 18;
  } else if (monster.rareType === "material") {
    ctx.save();
    ctx.shadowColor = "#ffd700";
    ctx.shadowBlur = 12;
  }

  ctx.fillStyle = monster.color;
  ctx.beginPath();
  ctx.arc(monster.x, monster.y, monster.radius, 0, Math.PI * 2);
  ctx.fill();

  if (monster.rareType === "sparkle") {
    const hue = (gameTime * 180) % 360;
    ctx.lineWidth = 4;
    ctx.strokeStyle = `hsl(${hue}, 100%, 65%)`;
    ctx.stroke();

    ctx.fillStyle = "#ffffff";
    for (let i = 0; i < 5; i++) {
      const pAngle = gameTime * 3 + (i * Math.PI * 2) / 5;
      const pDist = monster.radius + 10 + Math.sin(gameTime * 4 + i) * 4;
      const px = monster.x + Math.cos(pAngle) * pDist;
      const py = monster.y + Math.sin(pAngle) * pDist;
      ctx.beginPath();
      ctx.arc(px, py, 2, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  } else if (monster.rareType === "material") {
    ctx.lineWidth = 4;
    ctx.strokeStyle = "#ffd700";
    ctx.stroke();
    ctx.restore();
  }

  const barWidth = monster.radius * 2;
  const barHeight = 5;
  const barX = monster.x - monster.radius;
  const barY = monster.y - monster.radius - barHeight - 6;
  const hpRatio = Math.max(0, monster.hp / monster.maxHp);

  ctx.fillStyle = "#333333";
  ctx.fillRect(barX, barY, barWidth, barHeight);
  ctx.fillStyle = "#e05c5c";
  ctx.fillRect(barX, barY, barWidth * hpRatio, barHeight);
}

function drawOffscreenIndicators(ctx, camera, monsters) {
  const margin = 30;
  const w = ctx.canvas.width;
  const h = ctx.canvas.height;
  const cx = w / 2;
  const cy = h / 2;

  for (const m of monsters) {
    if (!m.alive || !m.rareType) continue;
    const sx = m.x - camera.x;
    const sy = m.y - camera.y;
    if (sx >= margin && sx <= w - margin && sy >= margin && sy <= h - margin) continue;

    const angle = Math.atan2(sy - cy, sx - cx);
    const dx = Math.cos(angle);
    const dy = Math.sin(angle);
    const scaleX = dx !== 0 ? (w / 2 - margin) / Math.abs(dx) : Infinity;
    const scaleY = dy !== 0 ? (h / 2 - margin) / Math.abs(dy) : Infinity;
    const scale = Math.min(scaleX, scaleY);
    const ax = cx + dx * scale;
    const ay = cy + dy * scale;

    ctx.save();
    ctx.translate(ax, ay);
    ctx.rotate(angle);
    ctx.fillStyle = m.rareType === "sparkle" ? "#ff66ff" : "#ffd700";
    ctx.strokeStyle = "#000000";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(12, 0);
    ctx.lineTo(-8, -8);
    ctx.lineTo(-8, 8);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }
}

function drawDamageNumbers(ctx, damageNumbers) {
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  for (const dn of damageNumbers) {
    const alpha = Math.max(0, 1 - dn.age / BALANCE.damageNumberLifetime);
    ctx.globalAlpha = alpha;
    ctx.fillStyle = "#ffffff";
    const fontSize = (dn.isCrit ? 30 : 20) + (dn.isComboHit ? 6 : 0);
    ctx.font = `${dn.isCrit ? "bold " : ""}${fontSize}px sans-serif`;
    ctx.fillText(formatAbbreviatedNumber(dn.value), dn.x, dn.y);
  }
  ctx.globalAlpha = 1;
}

function drawEnhanceInfo(ctx, weaponLevel, resultText, resultTimer, gold) {
  ctx.fillStyle = "#ffffff";
  ctx.font = "16px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  ctx.fillText(`강화 +${weaponLevel}`, 10, 10);
  ctx.fillText(`골드 ${formatAbbreviatedNumber(gold)}`, 10, 32);

  if (resultTimer > 0) {
    ctx.font = "bold 20px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(resultText, ctx.canvas.width / 2, 40);
  }
}

// 던전 선택 버튼(top:8px, HTML) 아래 20px 여백을 두고 표시 (상단 중앙 레이아웃)
const BOSS_TIMER_Y = 54;

function drawBossTimer(ctx, timeRemaining, isPaused) {
  const minutes = Math.floor(timeRemaining / 60);
  const seconds = Math.floor(timeRemaining % 60);
  const text = `${minutes}:${String(seconds).padStart(2, "0")}`;

  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillStyle = isPaused ? "#888888" : "#ffe066";
  ctx.font = "bold 24px sans-serif";
  ctx.fillText(text, ctx.canvas.width / 2, BOSS_TIMER_Y);

  if (isPaused) {
    ctx.font = "12px sans-serif";
    ctx.fillText("대장간 - 정지", ctx.canvas.width / 2, BOSS_TIMER_Y + 26);
  }
}

function drawForgeNotice(ctx, text, y) {
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillStyle = "#ffffff";
  ctx.font = "14px sans-serif";
  ctx.fillText(text, ctx.canvas.width / 2, y === undefined ? 56 : y);
}

function drawBossCountdown(ctx, secondsRemaining) {
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = "#ff5c5c";
  ctx.font = "bold 40px sans-serif";
  ctx.fillText(`보스 등장까지 ${secondsRemaining}`, ctx.canvas.width / 2, ctx.canvas.height / 2);
}

function drawBoss(ctx, boss) {
  if (!boss || !boss.alive) return;
  if (boss.enraged) {
    ctx.save();
    ctx.shadowColor = "#ff0000";
    ctx.shadowBlur = 20;
  }
  ctx.fillStyle = boss.color;
  ctx.beginPath();
  ctx.arc(boss.x, boss.y, boss.radius, 0, Math.PI * 2);
  ctx.fill();
  if (boss.enraged) {
    ctx.lineWidth = 4;
    ctx.strokeStyle = "#ff0000";
    ctx.stroke();
    ctx.restore();
  }
}

function drawBossHealthBar(ctx, boss) {
  const width = ctx.canvas.width - 120;
  const height = 26;
  const x = 60;
  const y = 70;
  const ratio = Math.max(0, boss.hp / boss.maxHp);

  ctx.fillStyle = "#222222";
  ctx.fillRect(x, y, width, height);
  ctx.fillStyle = boss.enraged ? "#ff2222" : "#c94040";
  ctx.fillRect(x, y, width * ratio, height);
  ctx.strokeStyle = "#000000";
  ctx.lineWidth = 2;
  ctx.strokeRect(x, y, width, height);

  ctx.fillStyle = "#ffffff";
  ctx.font = "bold 16px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  const bossHpText = `${formatAbbreviatedNumber(Math.max(0, Math.ceil(boss.hp)))} / ${formatAbbreviatedNumber(boss.maxHp)}`;
  ctx.fillText(`${boss.name}  ${bossHpText}`, x + width / 2, y + height / 2);
}

function drawBossFightTimer(ctx, timeRemaining, failed) {
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillStyle = failed ? "#ff3333" : "#ffe066";
  ctx.font = "bold 20px sans-serif";
  ctx.fillText(failed ? "실패" : `보스전 제한시간 ${Math.ceil(timeRemaining)}`, ctx.canvas.width / 2, 100);
}

function drawEnrageVignette(ctx) {
  const w = ctx.canvas.width;
  const h = ctx.canvas.height;
  const grad = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) / 3, w / 2, h / 2, Math.max(w, h) / 1.3);
  grad.addColorStop(0, "rgba(255,0,0,0)");
  grad.addColorStop(1, "rgba(255,0,0,0.55)");
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, w, h);
}

function drawBossResult(ctx, result) {
  if (!result) return;
  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.6)";
  ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);

  const cx = ctx.canvas.width / 2;
  const cy = ctx.canvas.height / 2;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  if (result.type === "won") {
    ctx.fillStyle = "#ffe066";
    ctx.font = "bold 36px sans-serif";
    ctx.fillText(`클리어! ${result.grade}등급`, cx, cy - 60);

    ctx.fillStyle = "#ffffff";
    ctx.font = "18px sans-serif";
    ctx.fillText(`골드 +${formatAbbreviatedNumber(result.goldGained)}`, cx, cy - 20);
    if (result.gotTicket) {
      ctx.fillText(`확정 강화권 +1 획득`, cx, cy + 10);
    }
  } else {
    ctx.fillStyle = "#ff5c5c";
    ctx.font = "bold 36px sans-serif";
    ctx.fillText("실패", cx, cy - 60);

    ctx.fillStyle = "#ffffff";
    ctx.font = "18px sans-serif";
    if (result.retriesExhausted) {
      ctx.fillText("재도전 횟수를 모두 소진했습니다. 판 종료", cx, cy - 20);
    } else {
      ctx.fillText(`3분 추가 파밍 후 재도전 (${result.retriesUsed}/${result.maxRetries})`, cx, cy - 20);
    }
  }

  ctx.restore();
}

// 경험치 바 (메이플 스타일) - 화면 하단 전체 폭. 레벨업이 성장의 핵심 체감이라 항상 눈에 띄게
function drawWeaponExpBar(ctx, layout, level, progress) {
  const { x, y, w, h } = layout.expBar;

  ctx.fillStyle = "#1a1a1a";
  ctx.fillRect(x, y, w, h);
  ctx.fillStyle = "#66ccff";
  ctx.fillRect(x, y, w * progress.ratio, h);
  ctx.strokeStyle = "#000000";
  ctx.lineWidth = 1;
  ctx.strokeRect(x, y, w, h);

  ctx.textBaseline = "middle";
  ctx.lineWidth = 3;
  ctx.strokeStyle = "rgba(0,0,0,0.85)";
  ctx.fillStyle = "#ffe066";
  ctx.font = "bold 12px sans-serif";
  ctx.textAlign = "left";
  const levelText = `Lv.${level}`;
  ctx.strokeText(levelText, x + 6, y + h / 2 + 1);
  ctx.fillText(levelText, x + 6, y + h / 2 + 1);

  ctx.font = "12px sans-serif";
  ctx.textAlign = "center";
  ctx.fillStyle = "#ffffff";
  const label = progress.needed > 0
    ? `${formatAbbreviatedNumber(progress.current)} / ${formatAbbreviatedNumber(progress.needed)} (${Math.round(progress.ratio * 100)}%)`
    : "MAX";
  ctx.strokeText(label, x + w / 2, y + h / 2 + 1);
  ctx.fillText(label, x + w / 2, y + h / 2 + 1);
}

function drawAutoIndicator(ctx, autoMode) {
  if (!autoMode) return;
  ctx.fillStyle = "#ffe066";
  ctx.font = "bold 20px sans-serif";
  ctx.textAlign = "right";
  ctx.textBaseline = "top";
  ctx.fillText("AUTO", ctx.canvas.width - 10, 10);
}

// 등급 색상 - 태초(무지개)는 시간에 따라 색상환 순환
function resolveGradeColor(grade, gameTime) {
  const def = ITEM_GRADES[grade];
  return def.color === "rainbow" ? `hsl(${(gameTime * 180) % 360}, 100%, 60%)` : def.color;
}

// 바닥 장비 드랍 (PRD 7.1) - 등급 색상으로만 표시, 부위는 주운 뒤 확인
function drawGroundItems(ctx, groundItems, gameTime) {
  for (const item of groundItems) {
    const color = resolveGradeColor(item.grade, gameTime);
    const size = 10;
    ctx.save();
    ctx.shadowColor = color;
    ctx.shadowBlur = 14;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(item.x, item.y - size);
    ctx.lineTo(item.x + size, item.y);
    ctx.lineTo(item.x, item.y + size);
    ctx.lineTo(item.x - size, item.y);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = "#000000";
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.restore();
  }
}

// 경험치 토큰 (PRD 7.1-1) - 소/중/대 크기별 색상
function drawExpTokens(ctx, expTokens) {
  for (const token of expTokens) {
    const def = EXP_TOKEN_TIERS[token.size];
    ctx.save();
    ctx.shadowColor = def.color;
    ctx.shadowBlur = 8;
    ctx.fillStyle = def.color;
    ctx.beginPath();
    ctx.arc(token.x, token.y, def.radius, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

// 확률 강화권 바닥 드랍 (PRD 8.0-5) - 재료 몬스터가 드랍, 크기는 소/중/대 랜덤
function drawGroundTickets(ctx, groundTickets) {
  const color = ENHANCE_TICKET_TYPES.probability.color;
  for (const ticket of groundTickets) {
    const size = ENHANCE_TICKET_SIZES[ticket.size].radius;
    ctx.save();
    ctx.shadowColor = color;
    ctx.shadowBlur = 10;
    ctx.fillStyle = color;
    ctx.fillRect(ticket.x - size / 2, ticket.y - size / 2, size, size);
    ctx.strokeStyle = "#000000";
    ctx.lineWidth = 1;
    ctx.strokeRect(ticket.x - size / 2, ticket.y - size / 2, size, size);
    ctx.restore();
  }
}

function pointInRect(x, y, rect) {
  return x >= rect.x && x <= rect.x + rect.w && y >= rect.y && y <= rect.y + rect.h;
}

// 장비창 레이아웃 (PRD 7.3) - 클릭 판정(main.js)과 그리기가 같은 좌표를 쓰도록 공유
// offsetX: 대장간에서 강화 패널과 나란히 놓을 때 중앙에서 오른쪽으로 밀어내는 양 (main.js getInventoryOffsetX)
function getInventoryLayout(ctx, offsetX) {
  const w = ctx.canvas.width;
  const h = ctx.canvas.height;
  const panelW = 620;
  const panelH = 470;
  const px = w / 2 - panelW / 2 + (offsetX || 0);
  const py = h / 2 - panelH / 2;

  const filterY = py + 44;
  const filterCheckboxes = ITEM_GRADE_ORDER.map((grade, i) => ({
    grade,
    x: px + 16 + i * 82,
    y: filterY,
    w: 14,
    h: 14
  }));

  const equipSlotSize = 70;
  const equipGap = 40;
  const equipX = px + 30;
  const equipStartY = py + 90;
  const equipSlots = ITEM_PARTS.map((part, i) => ({
    part,
    x: equipX,
    y: equipStartY + i * (equipSlotSize + equipGap),
    w: equipSlotSize,
    h: equipSlotSize
  }));

  const cols = 5;
  const bagSlotSize = 56;
  const bagGap = 12;
  const bagAreaX = px + 190;
  const bagStartY = py + 90;
  const bagSlots = [];
  for (let i = 0; i < BALANCE.inventoryBagSize; i++) {
    const col = i % cols;
    const row = Math.floor(i / cols);
    bagSlots.push({
      index: i,
      x: bagAreaX + col * (bagSlotSize + bagGap),
      y: bagStartY + row * (bagSlotSize + bagGap),
      w: bagSlotSize,
      h: bagSlotSize
    });
  }

  // 일괄 판매 (요청사항 4) - 패널 우측 상단, 등급 드롭다운 + 버튼
  const bulkSellY = py + 14;
  const bulkSellBtnW = 150;
  const bulkSellDropdownW = 90;
  const bulkSellGap = 8;
  const bulkSellRight = px + panelW - 16;
  const bulkSellButton = { x: bulkSellRight - bulkSellBtnW, y: bulkSellY, w: bulkSellBtnW, h: 22 };
  const bulkSellDropdown = {
    x: bulkSellButton.x - bulkSellGap - bulkSellDropdownW, y: bulkSellY, w: bulkSellDropdownW, h: 22
  };
  const bulkSellOptions = BULK_SELLABLE_GRADES.map((grade, i) => ({
    grade,
    x: bulkSellDropdown.x,
    y: bulkSellDropdown.y + bulkSellDropdown.h + 2 + i * 24,
    w: bulkSellDropdown.w,
    h: 22
  }));

  return {
    px, py, panelW, panelH,
    filterCheckboxes, equipSlots, bagSlots,
    bulkSell: { button: bulkSellButton, dropdown: bulkSellDropdown, options: bulkSellOptions },
    statsY: py + panelH - 70,
    messageY: py + panelH - 44
  };
}

// 마우스가 올라간 슬롯 판정 - 클릭 처리(main.js)와 툴팁 표시(render.js) 양쪽에서 사용
function findHoveredInventorySlot(layout, mx, my) {
  for (const slot of layout.equipSlots) {
    if (pointInRect(mx, my, slot)) return { type: "equip", part: slot.part };
  }
  for (const slot of layout.bagSlots) {
    if (pointInRect(mx, my, slot)) return { type: "bag", index: slot.index };
  }
  return null;
}

function parseItemEffect(item) {
  const value = getItemStatValue(item);
  if (item.part === "armor") return { label: "방어력", valueRaw: value, text: `+${Math.round(value)}`, isPercent: false };
  if (item.part === "gloves") return { label: "공격력", valueRaw: value, text: `+${Math.round(value * 100)}%`, isPercent: true };
  return { label: "이동속도·공격속도", valueRaw: value, text: `+${Math.round(value * 100)}%`, isPercent: true };
}

// 착용 중인 같은 부위 장비와 비교 - 상승 초록 ▲, 하락 빨강 ▼ (PRD 7.3 개선)
function buildEffectSegments(item, comparisonItem) {
  const parsed = parseItemEffect(item);
  const baseText = `${parsed.label} ${parsed.text}`;
  if (!comparisonItem) return [{ text: baseText, color: "#ffffff" }];

  const compParsed = parseItemEffect(comparisonItem);
  const diff = parsed.valueRaw - compParsed.valueRaw;
  const diffText = parsed.isPercent
    ? `${diff >= 0 ? "+" : ""}${Math.round(diff * 100)}%`
    : `${diff >= 0 ? "+" : ""}${Math.round(diff)}`;
  const arrow = diff > 0 ? "▲" : diff < 0 ? "▼" : "－";
  const color = diff > 0 ? "#4dd97e" : diff < 0 ? "#ff5c5c" : "#aaaaaa";
  return [
    { text: baseText, color: "#ffffff" },
    { text: ` (착용 중 ${compParsed.text} ${arrow} ${diffText})`, color }
  ];
}

// 판매가 한 줄
function buildSellText(item) {
  const price = getItemSellValue(item);
  return `판매가: ${formatAbbreviatedNumber(price)}G`;
}

// 툴팁 레이아웃 - anchorSlot(장비창 슬롯 rect)에 붙여서 위치를 고정, 마우스를 따라다니지 않게 함
// (마우스를 따라다니면 판매 버튼 쪽으로 마우스를 움직이는 동안 버튼도 같이 밀려나 클릭 불가능해짐)
function getItemTooltipLayout(ctx, item, anchorSlot, comparisonItem) {
  const grade = ITEM_GRADES[item.grade];
  const plainLines = [
    `Lv${item.itemLevel} ${grade.name} ${ITEM_PART_NAMES[item.part]}`,
    `등급: ${grade.name}`,
    `부위: ${ITEM_PART_NAMES[item.part]}`
  ];
  const effectSegments = buildEffectSegments(item, comparisonItem);
  const sellText = buildSellText(item);

  ctx.save();
  ctx.font = "13px sans-serif";
  const padding = 8;
  const lineHeight = 18;
  const btnW = 56;
  const btnH = 22;
  const btnGap = 10;
  const effectLineWidth = effectSegments.reduce((sum, seg) => sum + ctx.measureText(seg.text).width, 0);
  const sellRowWidth = ctx.measureText(sellText).width + btnGap + btnW;
  const boxW = Math.max(
    ...plainLines.map((l) => ctx.measureText(l).width),
    effectLineWidth, sellRowWidth
  ) + padding * 2;
  const boxH = lineHeight * (plainLines.length + 2) + padding * 2;
  ctx.restore();

  let x = anchorSlot.x + anchorSlot.w + 8;
  let y = anchorSlot.y;
  if (x + boxW > ctx.canvas.width) x = anchorSlot.x - boxW - 8;
  if (y + boxH > ctx.canvas.height) y = ctx.canvas.height - boxH - 8;
  if (y < 0) y = 0;

  const sellY = y + padding + (plainLines.length + 1) * lineHeight;
  const sellBtn = { x: x + boxW - padding - btnW, y: sellY - 3, w: btnW, h: btnH };

  return {
    x, y, w: boxW, h: boxH, padding, lineHeight, plainLines, effectSegments,
    sellText, sellBtn
  };
}

function drawItemTooltip(ctx, item, layout, gameTime, isEquipped) {
  const {
    x, y, w, h, padding, lineHeight, plainLines, effectSegments, sellText, sellBtn
  } = layout;

  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.92)";
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = resolveGradeColor(item.grade, gameTime);
  ctx.lineWidth = 1.5;
  ctx.strokeRect(x, y, w, h);

  ctx.font = "13px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  plainLines.forEach((line, i) => {
    ctx.fillStyle = i === 0 ? resolveGradeColor(item.grade, gameTime) : "#ffffff";
    ctx.fillText(line, x + padding, y + padding + i * lineHeight);
  });

  let segX = x + padding;
  const segY = y + padding + plainLines.length * lineHeight;
  for (const seg of effectSegments) {
    ctx.fillStyle = seg.color;
    ctx.fillText(seg.text, segX, segY);
    segX += ctx.measureText(seg.text).width;
  }

  const sellY = y + padding + (plainLines.length + 1) * lineHeight;
  ctx.fillStyle = "#ffe066";
  ctx.fillText(sellText, x + padding, sellY);

  const btnColor = isEquipped ? "#666666" : "#4dd97e";
  ctx.fillStyle = "#222222";
  ctx.fillRect(sellBtn.x, sellBtn.y, sellBtn.w, sellBtn.h);
  ctx.strokeStyle = btnColor;
  ctx.lineWidth = 1.5;
  ctx.strokeRect(sellBtn.x, sellBtn.y, sellBtn.w, sellBtn.h);
  ctx.fillStyle = btnColor;
  ctx.font = "bold 12px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("판매", sellBtn.x + sellBtn.w / 2, sellBtn.y + sellBtn.h / 2 + 1);
  ctx.restore();
}

// 마우스가 슬롯 위 또는 그 슬롯의 툴팁(판매 버튼 포함) 위에 있으면 호버로 판정 -
// 툴팁이 슬롯에 고정돼 있으므로 버튼까지 마우스를 이동해도 호버가 끊기지 않음
// hoverSlot({type,part,index})의 아이템·툴팁 레이아웃을 계산 - 그리기(drawInventory)와
// 클릭 판정(main.js handleInventoryClick)이 같은 결과를 쓰도록 공유. hoverSlot 자체는 main.js가
// 프레임마다 갱신하는 "sticky" 상태(장비창 호버 상태 참고) - 여기서는 매 슬롯을 다시 스캔하지 않음
// (모든 슬롯의 툴팁 영역을 매번 검사하면, 착용 슬롯처럼 화면에 고정된 툴팁이 그 아래 가방 칸과
// 겹쳐서 엉뚱한 아이템의 툴팁이 뜨는 문제가 있었음)
function resolveHoveredTooltip(ctx, layout, equipment, bag, hoverSlot) {
  if (!hoverSlot) return null;
  const item = hoverSlot.type === "equip" ? equipment[hoverSlot.part] : bag[hoverSlot.index];
  if (!item) return null;
  const slotRect = hoverSlot.type === "equip"
    ? layout.equipSlots.find((s) => s.part === hoverSlot.part)
    : layout.bagSlots[hoverSlot.index];
  const comparisonItem = hoverSlot.type === "bag" ? equipment[item.part] : null;
  const tooltip = getItemTooltipLayout(ctx, item, slotRect, comparisonItem);
  return { item, tooltip, slotRect, isEquipped: hoverSlot.type === "equip" };
}

function wrapText(ctx, text, cx, y, maxWidth, lineHeight) {
  const words = text.split(" ");
  let line = "";
  let ty = y;
  for (const word of words) {
    const test = line ? `${line} ${word}` : word;
    if (line && ctx.measureText(test).width > maxWidth) {
      ctx.fillText(line, cx, ty);
      line = word;
      ty += lineHeight;
    } else {
      line = test;
    }
  }
  if (line) ctx.fillText(line, cx, ty);
  return ty + lineHeight;
}

// 하위 등급 착용 확인창 레이아웃 - 클릭 판정과 그리기가 같은 좌표를 쓰도록 공유
// offsetX는 장비창과 같은 값을 받는다 - 확인창은 장비창 조작에서만 뜨므로 장비창 중앙을 따라가야 강화 패널과 안 겹친다
function getConfirmDialogLayout(ctx, offsetX) {
  const w = ctx.canvas.width;
  const h = ctx.canvas.height;
  const boxW = 360;
  const boxH = 140;
  const cx = w / 2 + (offsetX || 0);
  const bx = cx - boxW / 2;
  const by = h / 2 - boxH / 2;
  const btnW = 100;
  const btnH = 36;
  const btnGap = 20;
  const btnY = by + boxH - 50;
  return {
    bx, by, boxW, boxH,
    confirmBtn: { x: cx - btnW - btnGap / 2, y: btnY, w: btnW, h: btnH },
    cancelBtn: { x: cx + btnGap / 2, y: btnY, w: btnW, h: btnH }
  };
}

function drawConfirmDialog(ctx, message, confirmLabel = "착용", confirmColor = "#4dd97e", offsetX = 0) {
  const layout = getConfirmDialogLayout(ctx, offsetX);
  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.6)";
  ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);

  ctx.fillStyle = "#1a1a1a";
  ctx.fillRect(layout.bx, layout.by, layout.boxW, layout.boxH);
  ctx.strokeStyle = "#ffe066";
  ctx.lineWidth = 2;
  ctx.strokeRect(layout.bx, layout.by, layout.boxW, layout.boxH);

  ctx.fillStyle = "#ffffff";
  ctx.font = "14px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  wrapText(ctx, message, layout.bx + layout.boxW / 2, layout.by + 20, layout.boxW - 30, 18);

  const drawBtn = (btn, label, color) => {
    ctx.fillStyle = "#333333";
    ctx.fillRect(btn.x, btn.y, btn.w, btn.h);
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.strokeRect(btn.x, btn.y, btn.w, btn.h);
    ctx.fillStyle = color;
    ctx.font = "bold 14px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(label, btn.x + btn.w / 2, btn.y + btn.h / 2);
  };
  drawBtn(layout.confirmBtn, confirmLabel, confirmColor);
  drawBtn(layout.cancelBtn, "취소", "#ff5c5c");
  ctx.restore();
}

// 드래그 중인 가방 아이템을 마우스 위치에 따라 그리는 고스트 아이콘
function drawDragGhost(ctx, item, mx, my, gameTime) {
  const color = resolveGradeColor(item.grade, gameTime);
  const size = 12;
  ctx.save();
  ctx.globalAlpha = 0.85;
  ctx.shadowColor = color;
  ctx.shadowBlur = 14;
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(mx, my - size);
  ctx.lineTo(mx + size, my);
  ctx.lineTo(mx, my + size);
  ctx.lineTo(mx - size, my);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = "#000000";
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.restore();
}

// 장비창 (PRD 7.3) - 왼쪽 착용 슬롯 3개 + 오른쪽 가방 20칸(등급 필터 적용), 하단 총 스탯, 호버 툴팁
function drawInventory(ctx, state) {
  const {
    equipment, bag, gameTime, mouseX, mouseY, totalStats, gradeFilter,
    pendingEquip, pendingSell, bulkSellConfirm, bulkSellGrade, bulkSellDropdownOpen, inventoryHoverSlot,
    invenMessage, invenMessageTimer, dragState, layoutOffsetX
  } = state;
  const layout = getInventoryLayout(ctx, layoutOffsetX);
  const { px, py, panelW, panelH } = layout;
  const draggedItem = dragState && dragState.dragging ? bag[dragState.bagIndex] : null;

  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.85)";
  ctx.fillRect(px, py, panelW, panelH);
  ctx.strokeStyle = "#888888";
  ctx.lineWidth = 2;
  ctx.strokeRect(px, py, panelW, panelH);

  ctx.fillStyle = "#ffffff";
  ctx.font = "bold 18px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  ctx.fillText("장비창 (I)", px + 16, py + 16);

  for (const cb of layout.filterCheckboxes) {
    const checked = gradeFilter[cb.grade];
    const color = resolveGradeColor(cb.grade, gameTime);
    ctx.fillStyle = checked ? color : "#222222";
    ctx.fillRect(cb.x, cb.y, cb.w, cb.h);
    ctx.strokeStyle = color;
    ctx.lineWidth = 1.5;
    ctx.strokeRect(cb.x, cb.y, cb.w, cb.h);
    ctx.fillStyle = checked ? "#ffffff" : "#888888";
    ctx.font = "11px sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "middle";
    ctx.fillText(ITEM_GRADES[cb.grade].name, cb.x + cb.w + 4, cb.y + cb.h / 2 + 1);
  }

  // 일괄 판매 (요청사항 4)
  const bs = layout.bulkSell;
  ctx.fillStyle = "#222222";
  ctx.fillRect(bs.dropdown.x, bs.dropdown.y, bs.dropdown.w, bs.dropdown.h);
  ctx.strokeStyle = "#888888";
  ctx.lineWidth = 1.5;
  ctx.strokeRect(bs.dropdown.x, bs.dropdown.y, bs.dropdown.w, bs.dropdown.h);
  ctx.fillStyle = "#ffffff";
  ctx.font = "12px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.fillText(`${ITEM_GRADES[bulkSellGrade].nameKo} ▼`, bs.dropdown.x + 8, bs.dropdown.y + bs.dropdown.h / 2 + 1);

  ctx.fillStyle = "#333333";
  ctx.fillRect(bs.button.x, bs.button.y, bs.button.w, bs.button.h);
  ctx.strokeStyle = "#ffe066";
  ctx.strokeRect(bs.button.x, bs.button.y, bs.button.w, bs.button.h);
  ctx.fillStyle = "#ffe066";
  ctx.font = "bold 12px sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("이 등급 이하 전부 판매", bs.button.x + bs.button.w / 2, bs.button.y + bs.button.h / 2 + 1);

  for (const slot of layout.equipSlots) {
    const item = equipment[slot.part];
    const isValidDropTarget = draggedItem && draggedItem.part === slot.part;
    ctx.fillStyle = "#222222";
    ctx.fillRect(slot.x, slot.y, slot.w, slot.h);
    ctx.strokeStyle = isValidDropTarget ? "#ffe066" : (item ? resolveGradeColor(item.grade, gameTime) : "#555555");
    ctx.lineWidth = isValidDropTarget ? 3 : 2;
    ctx.strokeRect(slot.x, slot.y, slot.w, slot.h);
    ctx.fillStyle = "#aaaaaa";
    ctx.font = "12px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "top";
    ctx.fillText(ITEM_PART_NAMES[slot.part], slot.x + slot.w / 2, slot.y + slot.h + 4);
    if (item) {
      ctx.fillStyle = "#ffe066";
      ctx.font = "bold 11px sans-serif";
      ctx.textAlign = "right";
      ctx.textBaseline = "top";
      ctx.fillText(`Lv${item.itemLevel}`, slot.x + slot.w - 3, slot.y + 3);
    }
  }

  for (const slot of layout.bagSlots) {
    const isDragSource = dragState && dragState.dragging && dragState.bagIndex === slot.index;
    const item = isDragSource ? null : bag[slot.index];
    const visible = item && gradeFilter[item.grade];
    ctx.fillStyle = "#222222";
    ctx.fillRect(slot.x, slot.y, slot.w, slot.h);
    ctx.strokeStyle = visible ? resolveGradeColor(item.grade, gameTime) : "#444444";
    ctx.lineWidth = 2;
    ctx.setLineDash(isDragSource ? [4, 3] : []);
    ctx.strokeRect(slot.x, slot.y, slot.w, slot.h);
    ctx.setLineDash([]);
    if (visible) {
      ctx.fillStyle = "#dddddd";
      ctx.font = "11px sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(ITEM_PART_NAMES[item.part], slot.x + slot.w / 2, slot.y + slot.h / 2);
      ctx.fillStyle = "#ffe066";
      ctx.font = "bold 11px sans-serif";
      ctx.textAlign = "right";
      ctx.textBaseline = "top";
      ctx.fillText(`Lv${item.itemLevel}`, slot.x + slot.w - 3, slot.y + 3);
    }
  }

  // 펼친 드롭다운 목록은 슬롯 위로 겹치므로 슬롯을 다 그린 뒤에 그린다 (먼저 그리면 아래쪽 옵션이 가방 칸에 덮인다)
  if (bulkSellDropdownOpen) {
    for (const opt of bs.options) {
      ctx.fillStyle = opt.grade === bulkSellGrade ? "#3a3a3a" : "#222222";
      ctx.fillRect(opt.x, opt.y, opt.w, opt.h);
      ctx.strokeStyle = "#666666";
      ctx.lineWidth = 1;
      ctx.strokeRect(opt.x, opt.y, opt.w, opt.h);
      ctx.fillStyle = "#ffffff";
      ctx.font = "12px sans-serif";
      ctx.textAlign = "left";
      ctx.textBaseline = "middle";
      ctx.fillText(ITEM_GRADES[opt.grade].nameKo, opt.x + 8, opt.y + opt.h / 2 + 1);
    }
  }

  ctx.fillStyle = "#ffe066";
  ctx.font = "14px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  ctx.fillText(
    `공격력 ${formatAbbreviatedNumber(totalStats.attack)}  /  방어력 ${formatAbbreviatedNumber(totalStats.defense)}  /  이동속도 ${totalStats.speed}`,
    px + 16,
    layout.statsY
  );

  if (invenMessageTimer > 0) {
    ctx.fillStyle = "#ff8080";
    ctx.font = "13px sans-serif";
    ctx.fillText(invenMessage, px + 16, layout.messageY);
  }
  ctx.restore();

  if (!pendingEquip && !pendingSell && !bulkSellConfirm && !draggedItem && !bulkSellDropdownOpen) {
    const resolved = resolveHoveredTooltip(ctx, layout, equipment, bag, inventoryHoverSlot);
    if (resolved) {
      drawItemTooltip(ctx, resolved.item, resolved.tooltip, gameTime, resolved.isEquipped);
    }
  }

  if (draggedItem) {
    drawDragGhost(ctx, draggedItem, mouseX, mouseY, gameTime);
  }

  if (pendingEquip) {
    drawConfirmDialog(ctx, "현재 착용중인 장비보다 낮은 등급입니다. 착용할까요?", "착용", "#4dd97e", layoutOffsetX);
  } else if (pendingSell) {
    drawConfirmDialog(ctx, pendingSell.message, "판매", "#ff5c5c", layoutOffsetX);
  } else if (bulkSellConfirm) {
    drawConfirmDialog(ctx, bulkSellConfirm.message, "판매", "#ff5c5c", layoutOffsetX);
  }
}
