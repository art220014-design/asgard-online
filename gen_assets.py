#!/usr/bin/env python3
"""Генерация пиксель-арта для игры кодом. Внешние ассеты не нужны."""
import os
import random
from PIL import Image, ImageDraw

random.seed(11)
BASE = "/home/user/ragnarok/assets"
for sub in ("tiles", "sprites", "icons"):
    os.makedirs(f"{BASE}/{sub}", exist_ok=True)


def save(img, path):
    img.save(path, "PNG", optimize=True)


def noise_tile(size, base, spread, seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (size, size), base + (255,))
    px = img.load()
    for y in range(size):
        for x in range(size):
            d = rnd.randint(-spread, spread)
            r, g, b, _ = px[x, y]
            px[x, y] = (max(0, min(255, r + d)), max(0, min(255, g + d)),
                        max(0, min(255, b + d)), 255)
    return img


TS = 64

grass = noise_tile(TS, (74, 122, 58), 14, 1)
d = ImageDraw.Draw(grass)
for _ in range(26):
    x, y = random.randint(2, TS - 3), random.randint(6, TS - 1)
    d.line([(x, y), (x - 1, y - 4)], fill=(96, 150, 72, 255))
save(grass, f"{BASE}/tiles/grass.png")

grass2 = noise_tile(TS, (66, 112, 52), 16, 2)
d = ImageDraw.Draw(grass2)
for _ in range(8):
    x, y = random.randint(6, TS - 6), random.randint(6, TS - 6)
    d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=(88, 138, 64, 255))
save(grass2, f"{BASE}/tiles/grass2.png")

save(noise_tile(TS, (198, 176, 118), 12, 3), f"{BASE}/tiles/sand.png")

stone = noise_tile(TS, (108, 108, 112), 10, 4)
d = ImageDraw.Draw(stone)
for _ in range(7):
    x, y = random.randint(4, TS - 14), random.randint(4, TS - 10)
    d.rectangle([x, y, x + random.randint(4, 10), y + random.randint(3, 7)],
                outline=(84, 84, 88, 255))
save(stone, f"{BASE}/tiles/stone.png")

water = noise_tile(TS, (46, 96, 150), 10, 5)
d = ImageDraw.Draw(water)
for _ in range(5):
    y = random.randint(4, TS - 12)
    d.arc([4, y, TS - 4, y + 8], 200, 340, fill=(86, 140, 190, 255))
save(water, f"{BASE}/tiles/water.png")

tree = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
d = ImageDraw.Draw(tree)
d.rectangle([TS // 2 - 5, TS // 2, TS // 2 + 5, TS - 4], fill=(88, 62, 38, 255))
for cx, cy, r, col in [(TS // 2, 22, 20, (44, 92, 48)), (TS // 2 - 12, 30, 13, (56, 110, 58)),
                       (TS // 2 + 12, 30, 13, (56, 110, 58)), (TS // 2, 16, 12, (70, 128, 66))]:
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (255,))
save(tree, f"{BASE}/tiles/tree.png")

rock = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
d = ImageDraw.Draw(rock)
d.polygon([(14, 50), (10, 32), (24, 18), (44, 20), (54, 38), (48, 52)], fill=(112, 112, 118, 255))
d.polygon([(24, 18), (44, 20), (38, 30), (22, 28)], fill=(134, 134, 140, 255))
save(rock, f"{BASE}/tiles/rock.png")


def hero(path, skin, cloth, hair, accent):
    W, H = 48, 60
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, H - 9, W - 10, H - 2], fill=(0, 0, 0, 70))
    d.rectangle([16, 42, 21, H - 8], fill=(52, 46, 42, 255))
    d.rectangle([26, 42, 31, H - 8], fill=(52, 46, 42, 255))
    d.rectangle([14, 24, 33, 44], fill=cloth + (255,))
    d.rectangle([14, 24, 33, 29], fill=accent + (255,))
    d.rectangle([9, 26, 14, 40], fill=cloth + (255,))
    d.rectangle([33, 26, 38, 40], fill=cloth + (255,))
    d.ellipse([15, 8, 33, 26], fill=skin + (255,))
    d.ellipse([15, 4, 33, 16], fill=hair + (255,))
    d.rectangle([19, 16, 21, 19], fill=(30, 30, 34, 255))
    d.rectangle([27, 16, 29, 19], fill=(30, 30, 34, 255))
    save(img, path)


hero(f"{BASE}/sprites/hero_sword.png", (232, 186, 152), (62, 92, 160), (86, 58, 34), (206, 178, 72))
hero(f"{BASE}/sprites/hero_mage.png", (238, 198, 166), (108, 62, 148), (58, 42, 30), (150, 110, 200))
hero(f"{BASE}/sprites/hero_archer.png", (226, 176, 140), (52, 118, 76), (140, 96, 44), (188, 160, 84))


def mob(path, body, dark, size=(48, 44), kind="blob"):
    W, H = size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([6, H - 8, W - 6, H - 1], fill=(0, 0, 0, 70))
    if kind == "blob":
        d.ellipse([6, 12, W - 6, H - 6], fill=body + (255,))
        d.ellipse([10, 16, W - 10, H - 16], fill=dark + (255,))
        d.rectangle([16, 24, 20, 29], fill=(240, 240, 240, 255))
        d.rectangle([28, 24, 32, 29], fill=(240, 240, 240, 255))
        d.rectangle([17, 25, 19, 28], fill=(20, 20, 20, 255))
        d.rectangle([29, 25, 31, 28], fill=(20, 20, 20, 255))
    elif kind == "beast":
        d.rectangle([8, 18, W - 8, H - 10], fill=body + (255,))
        d.ellipse([W - 20, 8, W - 4, 28], fill=body + (255,))
        d.polygon([(W - 16, 10), (W - 14, 2), (W - 8, 10)], fill=dark + (255,))
        d.polygon([(W - 10, 10), (W - 6, 2), (W - 2, 10)], fill=dark + (255,))
        for i in range(3):
            d.rectangle([10 + i * 9, H - 12, 16 + i * 9, H - 6], fill=dark + (255,))
        d.rectangle([W - 12, 14, W - 9, 18], fill=(250, 60, 60, 255))
    else:
        d.rectangle([8, 10, W - 8, H - 6], fill=body + (255,))
        d.rectangle([12, 14, W - 12, H - 10], fill=dark + (255,))
        d.rectangle([14, 20, 20, 26], fill=(255, 180, 60, 255))
        d.rectangle([W - 20, 20, W - 14, 26], fill=(255, 180, 60, 255))
        d.rectangle([4, 16, 10, H - 14], fill=body + (255,))
        d.rectangle([W - 10, 16, W - 4, H - 14], fill=body + (255,))
    save(img, path)


mob(f"{BASE}/sprites/mob_slime.png", (86, 186, 96), (58, 150, 72), kind="blob")
mob(f"{BASE}/sprites/mob_wolf.png", (118, 112, 104), (84, 78, 72), (56, 40), kind="beast")
mob(f"{BASE}/sprites/mob_golem.png", (128, 116, 100), (96, 86, 72), (52, 56), kind="golem")
mob(f"{BASE}/sprites/mob_boss.png", (150, 60, 70), (110, 40, 52), (72, 76), kind="golem")


def npc(path, cloth, hair):
    W, H = 48, 60
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, H - 9, W - 10, H - 2], fill=(0, 0, 0, 70))
    d.rectangle([14, 24, 33, H - 8], fill=cloth + (255,))
    d.ellipse([15, 8, 33, 26], fill=(230, 190, 156, 255))
    d.ellipse([14, 3, 34, 15], fill=hair + (255,))
    d.rectangle([19, 16, 21, 19], fill=(30, 30, 34, 255))
    d.rectangle([27, 16, 29, 19], fill=(30, 30, 34, 255))
    save(img, path)


npc(f"{BASE}/sprites/npc_shop.png", (140, 108, 60), (60, 44, 30))
npc(f"{BASE}/sprites/npc_quest.png", (86, 78, 130), (200, 196, 180))


def icon(path, painter):
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    painter(ImageDraw.Draw(img))
    save(img, path)


def draw_sword(d):
    d.polygon([(24, 4), (30, 12), (26, 34), (22, 34), (18, 12)], fill=(206, 210, 216, 255))
    d.rectangle([16, 32, 32, 36], fill=(140, 108, 60, 255))
    d.rectangle([22, 36, 26, 44], fill=(96, 74, 42, 255))


def draw_staff(d):
    d.rectangle([22, 10, 26, 44], fill=(120, 84, 50, 255))
    d.ellipse([16, 4, 32, 20], fill=(150, 110, 220, 255))
    d.ellipse([20, 8, 28, 16], fill=(220, 190, 255, 255))


def draw_bow(d):
    d.arc([8, 4, 40, 44], 300, 240, fill=(150, 110, 60, 255), width=4)
    d.line([(36, 6), (36, 42)], fill=(230, 230, 230, 255), width=2)
    d.line([(10, 24), (40, 24)], fill=(200, 200, 200, 255), width=2)


def draw_potion(d):
    d.rectangle([19, 6, 29, 14], fill=(150, 120, 90, 255))
    d.ellipse([12, 14, 36, 44], fill=(200, 60, 70, 255))
    d.ellipse([17, 19, 25, 29], fill=(240, 130, 140, 255))


def draw_attack(d):
    d.ellipse([10, 10, 38, 38], outline=(240, 200, 90, 255), width=3)
    d.ellipse([18, 18, 30, 30], fill=(240, 120, 90, 255))


def draw_skill_a(d):
    d.polygon([(24, 6), (34, 24), (24, 42), (14, 24)], fill=(120, 180, 240, 255))
    d.polygon([(24, 12), (30, 24), (24, 36), (18, 24)], fill=(200, 230, 255, 255))


def draw_skill_b(d):
    d.ellipse([8, 8, 40, 40], fill=(200, 90, 60, 255))
    d.ellipse([16, 16, 32, 32], fill=(250, 180, 80, 255))


def draw_skill_c(d):
    d.rectangle([10, 20, 38, 30], fill=(140, 220, 140, 255))
    d.polygon([(38, 20), (46, 25), (38, 30)], fill=(200, 250, 200, 255))
    d.rectangle([6, 14, 12, 36], fill=(90, 140, 90, 255))


def draw_bag(d):
    d.rectangle([10, 18, 38, 42], fill=(150, 110, 64, 255))
    d.arc([16, 8, 32, 26], 180, 360, fill=(110, 80, 46, 255), width=4)


def draw_coin(d):
    d.ellipse([10, 10, 38, 38], fill=(220, 180, 70, 255))
    d.ellipse([16, 16, 32, 32], fill=(255, 224, 130, 255))


for name, painter in [("sword", draw_sword), ("staff", draw_staff), ("bow", draw_bow),
                      ("potion", draw_potion), ("attack", draw_attack), ("skill_a", draw_skill_a),
                      ("skill_b", draw_skill_b), ("skill_c", draw_skill_c), ("bag", draw_bag),
                      ("coin", draw_coin)]:
    icon(f"{BASE}/icons/{name}.png", painter)

count = 0
for root, _, files in os.walk(BASE):
    for f in sorted(files):
        count += 1
print("PNG файлов:", count)
