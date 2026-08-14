// 게임 초기화 및 메인 루프 진입점
const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

const player = { x: canvas.width / 2, y: canvas.height / 2, radius: 20, speed: 200, angle: 0 };

const keys = {};
window.addEventListener("keydown", (e) => { keys[e.key.toLowerCase()] = true; });
window.addEventListener("keyup", (e) => { keys[e.key.toLowerCase()] = false; });

const mouse = { x: player.x, y: player.y };
canvas.addEventListener("mousemove", (e) => {
  const rect = canvas.getBoundingClientRect();
  mouse.x = e.clientX - rect.left;
  mouse.y = e.clientY - rect.top;
});

const projectiles = [];
function fireProjectile() {
  projectiles.push({
    x: player.x,
    y: player.y,
    angle: player.angle,
    radius: BALANCE.projectileRadius,
    traveled: 0
  });
}

let autoMode = false;
let attackTimer = 0;

function spawnMonster(x, y, type) {
  const data = MONSTERS[type];
  return {
    x, y, spawnX: x, spawnY: y, type,
    radius: data.radius,
    color: data.color,
    defense: data.defense,
    maxHp: data.hp,
    hp: data.hp,
    alive: true,
    respawnTimer: 0
  };
}

const monster = spawnMonster(canvas.width / 2 + 150, canvas.height / 2, "slime");
const RESPAWN_TIME = 3;

canvas.addEventListener("mousedown", (e) => {
  if (e.button !== 0) return;
  if (autoMode) return;
  fireProjectile();
});

canvas.addEventListener("dblclick", (e) => {
  if (e.button !== 0) return;
  autoMode = !autoMode;
  attackTimer = 0;
});

let lastTime = performance.now();

function update(dt) {
  let dx = 0, dy = 0;
  if (keys["w"]) dy -= 1;
  if (keys["s"]) dy += 1;
  if (keys["a"]) dx -= 1;
  if (keys["d"]) dx += 1;

  if (dx !== 0 || dy !== 0) {
    const len = Math.hypot(dx, dy);
    player.x += (dx / len) * player.speed * dt;
    player.y += (dy / len) * player.speed * dt;
  }

  player.angle = Math.atan2(mouse.y - player.y, mouse.x - player.x);

  if (autoMode) {
    attackTimer += dt;
    while (attackTimer >= BALANCE.attackInterval) {
      attackTimer -= BALANCE.attackInterval;
      fireProjectile();
    }
  }

  if (!monster.alive) {
    monster.respawnTimer -= dt;
    if (monster.respawnTimer <= 0) {
      monster.x = monster.spawnX;
      monster.y = monster.spawnY;
      monster.hp = monster.maxHp;
      monster.alive = true;
    }
  }

  for (let i = projectiles.length - 1; i >= 0; i--) {
    const p = projectiles[i];
    const step = BALANCE.projectileSpeed * dt;
    p.x += Math.cos(p.angle) * step;
    p.y += Math.sin(p.angle) * step;
    p.traveled += step;

    if (monster.alive && Math.hypot(p.x - monster.x, p.y - monster.y) <= p.radius + monster.radius) {
      const damage = calcDamage(BALANCE.playerAttack, monster.defense);
      monster.hp -= damage;
      projectiles.splice(i, 1);
      if (monster.hp <= 0) {
        monster.alive = false;
        monster.respawnTimer = RESPAWN_TIME;
      }
      continue;
    }

    if (p.traveled >= BALANCE.projectileRange) {
      projectiles.splice(i, 1);
    }
  }
}

function render() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  drawMonster(ctx, monster);
  drawPlayer(ctx, player);
  drawProjectiles(ctx, projectiles);
  drawAutoIndicator(ctx, autoMode);
}

function loop(now) {
  const dt = (now - lastTime) / 1000;
  lastTime = now;
  update(dt);
  render();
  requestAnimationFrame(loop);
}

requestAnimationFrame(loop);
