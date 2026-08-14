// 화면 그리기
function drawPlayer(ctx, player) {
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
}

function drawAutoIndicator(ctx, autoMode) {
  if (!autoMode) return;
  ctx.fillStyle = "#ffe066";
  ctx.font = "bold 20px sans-serif";
  ctx.textAlign = "right";
  ctx.textBaseline = "top";
  ctx.fillText("AUTO", ctx.canvas.width - 10, 10);
}
