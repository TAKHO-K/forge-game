// 화면 그리기
function drawMapFloor(ctx, mapWidth, mapHeight, wallThickness, forgeHeight) {
  ctx.fillStyle = "#2a2a2a";
  ctx.fillRect(wallThickness, wallThickness, mapWidth - wallThickness * 2, mapHeight - wallThickness * 2);

  ctx.fillStyle = "#3d3a5c";
  ctx.fillRect(wallThickness, wallThickness, mapWidth - wallThickness * 2, forgeHeight);

  ctx.strokeStyle = "#8877cc";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(wallThickness, wallThickness + forgeHeight);
  ctx.lineTo(mapWidth - wallThickness, wallThickness + forgeHeight);
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

function drawPlayerHealthBar(ctx, hp, maxHp, gameTime) {
  const slotWidth = 28;
  const slotHeight = 22;
  const gap = 4;
  const totalWidth = maxHp * slotWidth + (maxHp - 1) * gap;
  const startX = ctx.canvas.width / 2 - totalWidth / 2;
  const y = ctx.canvas.height - 90;

  const isLow = hp <= 3;
  const blinkOn = Math.floor(gameTime * 4) % 2 === 0;

  for (let i = 0; i < maxHp; i++) {
    const x = startX + i * (slotWidth + gap);
    ctx.fillStyle = i < hp ? "#e05c5c" : "#333333";
    ctx.fillRect(x, y, slotWidth, slotHeight);

    ctx.lineWidth = isLow && blinkOn ? 3 : 1;
    ctx.strokeStyle = isLow && blinkOn ? "#ff0000" : "#000000";
    ctx.strokeRect(x, y, slotWidth, slotHeight);
  }
}

function drawDashCooldown(ctx, cooldownTimer, cooldownMax) {
  const width = 80;
  const height = 10;
  const x = ctx.canvas.width / 2 - width / 2;
  const y = ctx.canvas.height - 30;
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
  ctx.textBaseline = "bottom";
  ctx.fillText(cooldownTimer <= 0 ? "대시 준비" : `대시 ${cooldownTimer.toFixed(1)}s`, x + width / 2, y - 4);
}

function drawProjectiles(ctx, projectiles) {
  ctx.fillStyle = "#ffe066";
  for (const p of projectiles) {
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
    ctx.fill();
  }
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
    ctx.font = dn.isCrit ? "bold 30px sans-serif" : "20px sans-serif";
    ctx.fillText(String(dn.value), dn.x, dn.y);
  }
  ctx.globalAlpha = 1;
}

function drawEnhanceInfo(ctx, weaponLevel, resultText, resultTimer, gold, totalAttack) {
  ctx.fillStyle = "#ffffff";
  ctx.font = "16px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  ctx.fillText(`강화 +${weaponLevel}`, 10, 10);
  ctx.fillText(`골드 ${gold}`, 10, 32);
  ctx.fillText(`공격력 ${totalAttack}`, 10, 54);

  if (resultTimer > 0) {
    ctx.font = "bold 20px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(resultText, ctx.canvas.width / 2, 40);
  }
}

function drawBossTimer(ctx, timeRemaining, isPaused) {
  const minutes = Math.floor(timeRemaining / 60);
  const seconds = Math.floor(timeRemaining % 60);
  const text = `${minutes}:${String(seconds).padStart(2, "0")}`;

  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillStyle = isPaused ? "#888888" : "#ffe066";
  ctx.font = "bold 24px sans-serif";
  ctx.fillText(text, ctx.canvas.width / 2, 10);

  if (isPaused) {
    ctx.font = "12px sans-serif";
    ctx.fillText("대장간 - 정지", ctx.canvas.width / 2, 36);
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
  ctx.fillText(`${boss.name}  ${Math.max(0, Math.ceil(boss.hp))} / ${boss.maxHp}`, x + width / 2, y + height / 2);
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
    ctx.fillText(`골드 +${result.goldGained}`, cx, cy - 20);
    if (result.ticketCount > 0) {
      ctx.fillText(`확정 강화권 +${result.ticketValue} x${result.ticketCount} 획득`, cx, cy + 10);
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

function drawWeaponExpBar(ctx, level, progress) {
  const x = 10;
  const width = 150;
  const height = 14;
  const y = ctx.canvas.height - 64;
  const previewY = y + 15;
  const barY = previewY + 15;

  ctx.fillStyle = "#ffffff";
  ctx.font = "13px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  ctx.fillText(`무기 Lv.${level}`, x, y);

  // 다음 레벨 도달 시 얻는 공격력 증가분 미리보기
  const maxWeaponLevel = WEAPON_LEVEL_EXP.length;
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8fd6ff";
  if (level < maxWeaponLevel) {
    const nextLevel = level + 1;
    const gainRatio = getWeaponExpAttackMultiplier(nextLevel) - getWeaponExpAttackMultiplier(level);
    ctx.fillText(`Lv${nextLevel} → 공격력 +${Math.round(gainRatio * 100)}%`, x, previewY);
  } else {
    ctx.fillText("최대 레벨", x, previewY);
  }

  ctx.fillStyle = "#333333";
  ctx.fillRect(x, barY, width, height);
  ctx.fillStyle = "#66ccff";
  ctx.fillRect(x, barY, width * progress.ratio, height);
  ctx.strokeStyle = "#000000";
  ctx.lineWidth = 1;
  ctx.strokeRect(x, barY, width, height);

  ctx.fillStyle = "#ffffff";
  ctx.font = "11px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  const label = progress.needed > 0 ? `${progress.current} / ${progress.needed}` : "MAX";
  ctx.fillText(label, x + width / 2, barY + height / 2 + 1);
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

function pointInRect(x, y, rect) {
  return x >= rect.x && x <= rect.x + rect.w && y >= rect.y && y <= rect.y + rect.h;
}

// 장비창 레이아웃 (PRD 7.3) - 클릭 판정(main.js)과 그리기가 같은 좌표를 쓰도록 공유
function getInventoryLayout(ctx) {
  const w = ctx.canvas.width;
  const h = ctx.canvas.height;
  const panelW = 620;
  const panelH = 470;
  const px = w / 2 - panelW / 2;
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

  return {
    px, py, panelW, panelH,
    filterCheckboxes, equipSlots, bagSlots,
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

function drawItemTooltip(ctx, item, mx, my, gameTime, comparisonItem) {
  const grade = ITEM_GRADES[item.grade];
  const plainLines = [
    `${grade.name} ${ITEM_PART_NAMES[item.part]}`,
    `등급: ${grade.name}`,
    `부위: ${ITEM_PART_NAMES[item.part]}`
  ];
  const effectSegments = buildEffectSegments(item, comparisonItem);

  ctx.save();
  ctx.font = "13px sans-serif";
  const padding = 8;
  const lineHeight = 18;
  const effectLineWidth = effectSegments.reduce((sum, seg) => sum + ctx.measureText(seg.text).width, 0);
  const boxW = Math.max(...plainLines.map((l) => ctx.measureText(l).width), effectLineWidth) + padding * 2;
  const boxH = lineHeight * (plainLines.length + 1) + padding * 2;
  let tx = mx + 16;
  let ty = my + 16;
  if (tx + boxW > ctx.canvas.width) tx = mx - boxW - 16;
  if (ty + boxH > ctx.canvas.height) ty = my - boxH - 16;

  ctx.fillStyle = "rgba(0,0,0,0.92)";
  ctx.fillRect(tx, ty, boxW, boxH);
  ctx.strokeStyle = resolveGradeColor(item.grade, gameTime);
  ctx.lineWidth = 1.5;
  ctx.strokeRect(tx, ty, boxW, boxH);

  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  plainLines.forEach((line, i) => {
    ctx.fillStyle = i === 0 ? resolveGradeColor(item.grade, gameTime) : "#ffffff";
    ctx.fillText(line, tx + padding, ty + padding + i * lineHeight);
  });

  let segX = tx + padding;
  const segY = ty + padding + plainLines.length * lineHeight;
  for (const seg of effectSegments) {
    ctx.fillStyle = seg.color;
    ctx.fillText(seg.text, segX, segY);
    segX += ctx.measureText(seg.text).width;
  }
  ctx.restore();
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
function getConfirmDialogLayout(ctx) {
  const w = ctx.canvas.width;
  const h = ctx.canvas.height;
  const boxW = 360;
  const boxH = 140;
  const bx = w / 2 - boxW / 2;
  const by = h / 2 - boxH / 2;
  const btnW = 100;
  const btnH = 36;
  const btnGap = 20;
  const btnY = by + boxH - 50;
  return {
    bx, by, boxW, boxH,
    confirmBtn: { x: w / 2 - btnW - btnGap / 2, y: btnY, w: btnW, h: btnH },
    cancelBtn: { x: w / 2 + btnGap / 2, y: btnY, w: btnW, h: btnH }
  };
}

function drawConfirmDialog(ctx, message) {
  const layout = getConfirmDialogLayout(ctx);
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
  drawBtn(layout.confirmBtn, "착용", "#4dd97e");
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
  const { equipment, bag, gameTime, mouseX, mouseY, totalStats, gradeFilter, pendingEquip, invenMessage, invenMessageTimer, dragState } = state;
  const layout = getInventoryLayout(ctx);
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
    }
  }

  ctx.fillStyle = "#ffe066";
  ctx.font = "14px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  ctx.fillText(
    `공격력 ${totalStats.attack}  /  방어력 ${totalStats.defense}  /  이동속도 ${totalStats.speed}`,
    px + 16,
    layout.statsY
  );

  if (invenMessageTimer > 0) {
    ctx.fillStyle = "#ff8080";
    ctx.font = "13px sans-serif";
    ctx.fillText(invenMessage, px + 16, layout.messageY);
  }
  ctx.restore();

  if (!pendingEquip && !draggedItem) {
    const hovered = findHoveredInventorySlot(layout, mouseX, mouseY);
    if (hovered) {
      const item = hovered.type === "equip" ? equipment[hovered.part] : bag[hovered.index];
      const visible = hovered.type === "equip" ? !!item : !!(item && gradeFilter[item.grade]);
      if (visible) {
        const comparisonItem = hovered.type === "bag" ? equipment[item.part] : null;
        drawItemTooltip(ctx, item, mouseX, mouseY, gameTime, comparisonItem);
      }
    }
  }

  if (draggedItem) {
    drawDragGhost(ctx, draggedItem, mouseX, mouseY, gameTime);
  }

  if (pendingEquip) {
    drawConfirmDialog(ctx, "현재 착용중인 장비보다 낮은 등급입니다. 착용할까요?");
  }
}
