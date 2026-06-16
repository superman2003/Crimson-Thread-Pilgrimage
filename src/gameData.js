export const SETTINGS = {
  width: 960,
  height: 540,
  floorY: 456,
  gravity: 1850,
  playerMaxHealth: 8,
  levelWidth: 3260
};

const DEFAULT_KEYS = [
  { x: 420, y: 330 },
  { x: 1250, y: 334 },
  { x: 2110, y: 326 }
];

const DEFAULT_SHORTCUT = {
  lever: { x: 2390, y: 366, w: 58, h: 72 },
  bridge: { x: 2360, y: 342, w: 380, h: 18 },
  requiresKeys: 3
};

export const CHAPTERS = [
  {
    id: "moss-bell-court",
    roman: "I",
    name: "苔钟庭",
    shortName: "苔钟",
    objective: "收集钟钥，打开后门捷径，击败锈冠守卫",
    flow: "安全教学 -> 小考平台 -> 压力战斗 -> 安静回收 -> Boss 前捷径 -> Boss",
    keys: DEFAULT_KEYS,
    shortcut: DEFAULT_SHORTCUT,
    palette: {
      skyTop: "#173923",
      skyBottom: "#6a7b45",
      ground: "#24341d",
      groundAlt: "#64733d",
      accent: "#d5bd62",
      danger: "#afe36f",
      mist: "rgba(157, 211, 104, 0.22)"
    },
    motif: "苔藓旧庭、钟钥与锈冠守卫",
    spawn: { x: 120, y: 380 },
    exit: { x: 3090, y: 372 },
    platforms: [
      [360, 382, 260, 24],
      [760, 322, 220, 22],
      [1150, 386, 300, 24],
      [1580, 314, 260, 22],
      [1980, 376, 260, 24],
      [2350, 300, 260, 22],
      [2700, 396, 240, 24]
    ],
    hazards: [
      { type: "mist", x: 630, y: 420, w: 250, h: 70 },
      { type: "mist", x: 1760, y: 420, w: 300, h: 70 }
    ],
    enemies: [
      { kind: "crawler", name: "苔牙幼虫", x: 520, y: 420, range: 160 },
      { kind: "flyer", name: "铜翅蛾", x: 915, y: 240, range: 180 },
      { kind: "shooter", name: "孢囊钟匠", x: 1330, y: 338, range: 250 },
      { kind: "crawler", name: "苔牙幼虫", x: 2060, y: 420, range: 190 },
      { kind: "flyer", name: "铜翅蛾", x: 2510, y: 250, range: 170 }
    ],
    boss: { name: "锈冠守卫", x: 2910, y: 330, hp: 38, pattern: "bell" }
  },
  {
    id: "rain-foundry-canal",
    roman: "II",
    name: "铸雨渠",
    shortName: "铸雨",
    objective: "打开水轮捷径，击败沉锤铁匠",
    flow: "雨渠低台 -> 管道小考 -> 水轮压力 -> 休息回收 -> Boss 前捷径 -> 铁匠战",
    keys: DEFAULT_KEYS,
    shortcut: DEFAULT_SHORTCUT,
    palette: {
      skyTop: "#0c2742",
      skyBottom: "#3f8aa1",
      ground: "#173346",
      groundAlt: "#7fd5e4",
      accent: "#e7fbff",
      danger: "#91f7ff",
      mist: "rgba(145, 247, 255, 0.18)"
    },
    motif: "雨渠、水轮、湿锈与铁匠印记",
    spawn: { x: 120, y: 380 },
    exit: { x: 3090, y: 372 },
    platforms: [
      [310, 360, 220, 20],
      [650, 298, 220, 20],
      [1020, 386, 240, 20],
      [1380, 318, 300, 20],
      [1830, 360, 200, 20],
      [2180, 286, 260, 20],
      [2620, 386, 260, 20]
    ],
    hazards: [
      { type: "shards", x: 560, y: 440, w: 210, h: 28 },
      { type: "shards", x: 1690, y: 440, w: 260, h: 28 },
      { type: "shards", x: 2450, y: 440, w: 220, h: 28 }
    ],
    enemies: [
      { kind: "crawler", name: "排水蛭", x: 480, y: 420, range: 170 },
      { kind: "shooter", name: "管道投掷者", x: 1110, y: 420, range: 250 },
      { kind: "flyer", name: "锈潜者", x: 1510, y: 270, range: 170 },
      { kind: "crawler", name: "钟沫虫", x: 2050, y: 420, range: 160 },
      { kind: "charger", name: "水轮骑士", x: 2730, y: 420, range: 180 }
    ],
    boss: { name: "沉锤铁匠", x: 2900, y: 318, hp: 44, pattern: "tide" }
  },
  {
    id: "saltwhite-archive",
    roman: "III",
    name: "盐白书库",
    shortName: "盐白",
    objective: "找到王冠契约原本，击败盐白契约官",
    flow: "书库入口 -> 档案跳台 -> 索引战斗 -> 静室补给 -> Boss 前捷径 -> 契约战",
    keys: DEFAULT_KEYS,
    shortcut: DEFAULT_SHORTCUT,
    palette: {
      skyTop: "#3a1010",
      skyBottom: "#a94b2b",
      ground: "#3b211b",
      groundAlt: "#ffb15c",
      accent: "#ffd39c",
      danger: "#ff5b35",
      mist: "rgba(255, 102, 47, 0.2)"
    },
    motif: "盐晶档案、违影与契约法庭",
    spawn: { x: 120, y: 380 },
    exit: { x: 3090, y: 372 },
    platforms: [
      [360, 392, 220, 24],
      [720, 324, 230, 22],
      [1070, 360, 220, 24],
      [1440, 292, 270, 22],
      [1840, 380, 260, 24],
      [2250, 318, 220, 22],
      [2660, 386, 270, 24]
    ],
    hazards: [
      { type: "lava", x: 590, y: 444, w: 260, h: 32 },
      { type: "lava", x: 1710, y: 444, w: 310, h: 32 },
      { type: "lava", x: 2480, y: 444, w: 180, h: 32 }
    ],
    enemies: [
      { kind: "crawler", name: "盐书蠹", x: 510, y: 420, range: 150 },
      { kind: "flyer", name: "书页决斗者", x: 830, y: 276, range: 180 },
      { kind: "shooter", name: "索引书记", x: 1260, y: 420, range: 260 },
      { kind: "charger", name: "封蜡枪兵", x: 2000, y: 420, range: 180 },
      { kind: "charger", name: "删名执达吏", x: 2600, y: 420, range: 200 }
    ],
    boss: { name: "盐白契约官", x: 2910, y: 320, hp: 50, pattern: "mirror" }
  },
  {
    id: "broken-string-greenhouse",
    roman: "IV",
    name: "断弦温室",
    shortName: "断弦",
    objective: "穿越藤蔓温室，击败断弦园主",
    flow: "温室入口 -> 风喷小考 -> 藤蔓战斗 -> 暖室回收 -> Boss 前捷径 -> 园主战",
    keys: DEFAULT_KEYS,
    shortcut: DEFAULT_SHORTCUT,
    palette: {
      skyTop: "#17193a",
      skyBottom: "#7761a8",
      ground: "#232640",
      groundAlt: "#c6d7f3",
      accent: "#f6f2cf",
      danger: "#a6ecff",
      mist: "rgba(170, 223, 255, 0.2)"
    },
    motif: "藤桥、花粉风与断弦印记",
    spawn: { x: 120, y: 380 },
    exit: { x: 3090, y: 372 },
    platforms: [
      [310, 384, 240, 22],
      [700, 314, 260, 20],
      [1100, 370, 240, 22],
      [1470, 286, 220, 20],
      [1840, 342, 300, 22],
      [2290, 286, 240, 20],
      [2640, 386, 260, 22]
    ],
    hazards: [
      { type: "geyser", x: 610, y: 430, w: 80, h: 70, phase: 0 },
      { type: "geyser", x: 1580, y: 430, w: 80, h: 70, phase: 1.3 },
      { type: "geyser", x: 2390, y: 430, w: 80, h: 70, phase: 2.2 }
    ],
    enemies: [
      { kind: "crawler", name: "藤蔓爬行者", x: 520, y: 420, range: 170 },
      { kind: "flyer", name: "蜂蜡蛾", x: 1210, y: 250, range: 180 },
      { kind: "shooter", name: "根笛猎手", x: 1540, y: 238, range: 270 },
      { kind: "shooter", name: "花粉琴师", x: 2050, y: 245, range: 170 },
      { kind: "charger", name: "棘藤哨兵", x: 2680, y: 420, range: 190 }
    ],
    boss: { name: "断弦园主", x: 2900, y: 315, hp: 54, pattern: "wind" }
  },
  {
    id: "obsidian-pilgrim-road",
    roman: "V",
    name: "黑曜巡礼道",
    shortName: "黑曜",
    objective: "穿过巡礼军阵，击败静音巡礼统帅",
    flow: "旌旗入口 -> 风门小考 -> 军阵战斗 -> 影门回收 -> Boss 前捷径 -> 统帅战",
    keys: DEFAULT_KEYS,
    shortcut: DEFAULT_SHORTCUT,
    palette: {
      skyTop: "#112f31",
      skyBottom: "#b6c7a1",
      ground: "#2b3126",
      groundAlt: "#e7e1c8",
      accent: "#65e0bd",
      danger: "#d9f0e0",
      mist: "rgba(226, 238, 208, 0.18)"
    },
    motif: "黑曜旗、影门与沉默军令",
    spawn: { x: 120, y: 380 },
    exit: { x: 3090, y: 372 },
    platforms: [
      [350, 352, 240, 22],
      [720, 274, 220, 20],
      [1060, 392, 240, 22],
      [1440, 312, 260, 20],
      [1840, 240, 220, 20],
      [2180, 356, 300, 22],
      [2650, 306, 260, 20]
    ],
    hazards: [
      { type: "wind", x: 630, y: 230, w: 120, h: 230, force: -260 },
      { type: "wind", x: 1700, y: 210, w: 140, h: 250, force: 280 },
      { type: "wind", x: 2500, y: 210, w: 120, h: 250, force: -260 }
    ],
    enemies: [
      { kind: "charger", name: "黑曜长枪兵", x: 520, y: 420, range: 220 },
      { kind: "shooter", name: "相位审查者", x: 830, y: 226, range: 270 },
      { kind: "crawler", name: "静音号手", x: 1220, y: 420, range: 170 },
      { kind: "flyer", name: "跪巡兵", x: 2140, y: 260, range: 180 },
      { kind: "charger", name: "巡礼战车", x: 2740, y: 420, range: 220 }
    ],
    boss: { name: "静音巡礼统帅", x: 2900, y: 300, hp: 58, pattern: "ember" }
  },
  {
    id: "silent-crown-core",
    roman: "VI",
    name: "无声王冠",
    shortName: "王冠",
    objective: "进入王冠核心，决定钟声命运",
    flow: "回声入口 -> 核心小考 -> 回响战斗 -> 静默回收 -> Boss 前捷径 -> 王冠战",
    keys: DEFAULT_KEYS,
    shortcut: DEFAULT_SHORTCUT,
    palette: {
      skyTop: "#080713",
      skyBottom: "#231041",
      ground: "#151221",
      groundAlt: "#8e5eff",
      accent: "#ff5dc8",
      danger: "#7efcff",
      mist: "rgba(255, 93, 200, 0.16)"
    },
    motif: "五章回声、黑潮童声与三结局",
    spawn: { x: 120, y: 380 },
    exit: { x: 3090, y: 372 },
    platforms: [
      [320, 386, 220, 20],
      [670, 308, 220, 20],
      [1010, 246, 220, 20],
      [1370, 356, 260, 20],
      [1780, 286, 240, 20],
      [2180, 390, 260, 20],
      [2630, 316, 270, 20]
    ],
    hazards: [
      { type: "void", x: 610, y: 398, w: 170, h: 60, phase: 0.2 },
      { type: "void", x: 1660, y: 400, w: 220, h: 60, phase: 1.2 },
      { type: "void", x: 2460, y: 400, w: 230, h: 60, phase: 2.4 }
    ],
    enemies: [
      { kind: "crawler", name: "苔庭回声", x: 520, y: 420, range: 170 },
      { kind: "charger", name: "水轮骑士回声", x: 890, y: 420, range: 220 },
      { kind: "shooter", name: "契约书记回声", x: 1500, y: 308, range: 300 },
      { kind: "charger", name: "棘藤哨兵回声", x: 2220, y: 420, range: 170 },
      { kind: "flyer", name: "同位光影", x: 2700, y: 250, range: 170 }
    ],
    boss: { name: "无声王冠", x: 2900, y: 300, hp: 66, pattern: "core" }
  }
];
