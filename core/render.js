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

function drawMonster(ctx, monster) {
  if (!monster.alive) return;
  ctx.fillStyle = monster.color;
  ctx.beginPath();
  ctx.arc(monster.x, monster.y, monster.radius, 0, Math.PI * 2);
  ctx.fill();

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

function drawForgeNotice(ctx, text) {
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillStyle = "#ffffff";
  ctx.font = "14px sans-serif";
  ctx.fillText(text, ctx.canvas.width / 2, 56);
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
  const y = ctx.canvas.height - 50;
  const barY = y + 16;

  ctx.fillStyle = "#ffffff";
  ctx.font = "13px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  ctx.fillText(`무기 Lv.${level}`, x, y);

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
