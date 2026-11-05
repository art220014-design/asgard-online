"""Чтение GAT (Ragnarok Online, версии 1.2 и 1.3) по спецификации RagnarokFileFormats.

Формат: "GRAT" (4 байта), версия (2 байта, major.minor), ширина и высота (int32),
затем по 20 байт на тайл: 4 высоты (float32) и тип тайла (uint32).
Тип тайла: младший байт — проходимость (0 — ходьба, 1 — препятствие, 5 — обрыв);
в версии 1.3 старший байт 0x80 означает водную поверхность.
"""
import struct
from dataclasses import dataclass, field

WALKABLE = 0
OBSTRUCTED = 1
CLIFF = 5


@dataclass
class Tile:
    heights: tuple          # (лев.низ, прав.низ, лев.верх, прав.верх)
    flag: int               # младший байт типа тайла
    water: bool = False     # только версия 1.3


@dataclass
class Gat:
    version: tuple
    width: int
    height: int
    tiles: list = field(default_factory=list)

    def tile(self, x: int, y: int) -> Tile:
        return self.tiles[y * self.width + x]

    def walkable(self, x: int, y: int) -> bool:
        if x < 0 or y < 0 or x >= self.width or y >= self.height:
            return False
        return self.tile(x, y).flag == WALKABLE


def parse(data: bytes) -> Gat:
    if len(data) < 14 or data[:4] != b"GRAT":
        raise ValueError("не GAT-файл: нет сигнатуры GRAT")
    major, minor = data[4], data[5]
    if (major, minor) not in ((1, 2), (1, 3)):
        raise ValueError("неизвестная версия GAT: %d.%d" % (major, minor))
    width, height = struct.unpack_from("<ii", data, 6)
    if width <= 0 or height <= 0 or width * height > 1_000_000:
        raise ValueError("некорректные размеры карты: %dx%d" % (width, height))
    need = 14 + width * height * 20
    if len(data) < need:
        raise ValueError("файл обрезан: нужно %d байт, есть %d" % (need, len(data)))
    g = Gat((major, minor), width, height)
    off = 14
    for _ in range(width * height):
        h0, h1, h2, h3, raw = struct.unpack_from("<ffffI", data, off)
        off += 20
        g.tiles.append(Tile(
            heights=(h0, h1, h2, h3),
            flag=raw & 0xFF,
            water=(minor == 3 and ((raw >> 8) & 0xFF) == 0x80),
        ))
    return g


def build(width: int, height: int, flags, version=(1, 2)) -> bytes:
    """Собрать GAT из матрицы флагов (для тестов и генерации). flags[y][x] -> 0/1/5."""
    out = bytearray(b"GRAT")
    out += bytes(version)
    out += struct.pack("<ii", width, height)
    for y in range(height):
        for x in range(width):
            out += struct.pack("<ffffI", 0.0, 0.0, 0.0, 0.0, int(flags[y][x]))
    return bytes(out)
