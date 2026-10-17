# moss_larva：受击恢复与死亡倒地关键帧

内置 image_gen 生成，保留原始透明 RGBA PNG。上行受击恢复4帧，下行死亡倒地4帧。

按 generation_manifest.json 的 region 和全图坐标 component_seed 取帧：alpha>24 的8连通轮廓，再保留3px低alpha边缘并排除其他实心轮廓。矩形可能交错，不能机械等分或直接裁矩形。

源图、提示词、参考图哈希和逐帧哈希随同上传。尚未接入运行时，比例、锚点、时长和连播仍待验证；不宣称游戏测试通过。
