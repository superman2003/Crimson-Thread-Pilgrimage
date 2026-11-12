## 2026-11-12：双线跃在工房外有了第一处可选高架（A01）

双线跃原先只守自己的两间工房，在正常房间里没有用处。新增 `world_routes.json` 的 `ability_ledges` 清单：在盐白档案馆中庭书塔西侧二层（`f2_gap_ledge`）上方 188 像素处加一层单向孤架，架上放 5 份盐晶，作为可选探索奖励；房间说明补一句“单跳够不着”的提示。不改主线、不加必经门。

新增 `tools/audit_ability_ledges.py`（并入 `test:campaign`），按玩家真实起跳数值（单跳约 136、二段跳约 250 像素）留足余量，逐处证明：底板单跳不够、二段跳够得着；全区其他可站立表面单跳加冲刺都够不着；附近没有能贴墙蹬上去的高墙、没有钩环；起跳竖井和架上头顶没有实体；奖励落在架上。用同一审计扫描六区全部房间，只有这一处在现有几何下没有绕过路线，其余候选都会被旁边的台阶、墙或坡面绕过，需要改动周边几何才能再加。

新增 Godot 套件 `ability_ledges`：按数据坐标重建底板和孤架，用真实跳跃输入验证未取得双线跃时落回底板、取得后落到架上，并补单跳不得拾取、双线跃落架且拾取的断言，六项由合同 CI 核验。`audit_stranding`、`audit_shortcut_bypass`、`audit_economy`（收入 2840）、`validate_world_routes`、`validate_world_upgrade` 及 `ability_movement`、`salt_archive_experience`、`pickup_ledger`、`world_route_access` 通过。

审查复现：原坐标下单跳虽落不上架子，84px 身体与半径18的拾取圈仍重叠，盐晶可被提前拿走。孤架上移12px到1594，奖励上移到1524（架上70px），静态审计加入身体与拾取半径的余量；Godot4.6 最小物理复现原版单跳拾取得到、修正版单跳拾取不到、二段跳可拾取并落架。新增 .github/contracts/ability-ledges.yml 将新套件及能力移动、拾取回归接入 Linux CI，保持既有检查。
