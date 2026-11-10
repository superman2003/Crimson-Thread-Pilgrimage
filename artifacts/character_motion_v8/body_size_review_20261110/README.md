# 全角色尺寸与评论回归复查

来源：[PR 评论](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/580#issuecomment-6758694814)，旧提交 `dba405b402ce9c9a82501fe93a70ebee6e57c09b`。评论中的 222 组旧像素数已由实际 Git 对象复核，全部吻合。

- `body_review.json`：全 46 角色、5,439 张新增姿势的尺寸、完整画布与面积门槛汇总。
- `reviewed_regressions.json`：222 处旧统计、旧图复核和修复后统计。
- `review_cases_01.jpg` 至 `review_cases_19.jpg`：全部 222 处的左／新／右三帧对照；每组始终使用同一缩放比例。
- `roster_01.jpg` 至 `roster_08.jpg`：全部角色的待机、移动、攻击、受击素材和死亡取样；同一角色各格采用同一比例。

硬门槛比较 alpha > 128 的像素面积，参照两端的几何平均，范围 [0.67, 1.5]；超限或画布越界会使检查失败。另记录主体材质／面积的校准结果；这些测量不等于逐动作姿态设计的完整视觉验收。

重现（`--verify-previous` 需要本地旧提交历史；浅克隆可省略该选项）：

```powershell
python -X utf8 tools/review_character_body_scale.py --verify-previous
python -X utf8 tools/build_character_motion_v8.py --check
```
