## 2026-11-15：串行导入素材，规避CI冷导入堆损坏（T03 CI稳定性）

PR663的Godot integration regressions运行43710191132中，runtime(1)在资源导入97%、最后进度标签NotoSansSC.ttf附近，以SIGABRT／exit=-6退出，原始日志为“double free or corruption (fasttop)”，没有Godot脚本错误。该分片后续全部运行回归成功，另两分片、视觉、原生合同和三平台发布构建均成功；此前的LFS拉取问题已由35b6535e6修复，不重复归因于素材缺失。

在project.godot设置editor/import/use_multiple_threads=false，采用Godot4.6.1支持的串行资源导入路径，规避并发导入风险。这是针对引擎导入阶段的防护；现有日志没有符号化堆栈，不能断言具体字体或分配器调用就是根因。保留run_godot_import.py原有两遍导入、非零退出、ERROR／SCRIPT ERROR与超时拒绝，不新增重试、忽略失败或修改workflow。

依据：[4.6.1导入实现](https://github.com/godotengine/godot/blob/4.6.1-stable/editor/file_system/editor_file_system.cpp)、[ProjectSettings说明](https://github.com/godotengine/godot/blob/4.6.1-stable/doc/classes/ProjectSettings.xml)及[上游并发导入问题](https://github.com/godotengine/godot/issues/109374)。Windows Godot4.6.1以三张正式图集和两套实际字体作隔离冷、暖两遍导入，均通过；原生探针确认串行设置已生效。这是设置生效与代表性导入验证，不冒充原Linux崩溃复现；完整项目结果由本次CI确认。

集成workflow6项与LFS workflow5项、合同lint和台账格式通过。本地import工具的11项Unix进程夹具在Windows按既有条件跳过；合同工具16项中5项受Windows符号链接权限限制，未计为通过，LinuxCI继续执行完整检查。

5568c93e3的完整工程CI中，visual两遍串行导入于589秒成功，runtime(1)也通过导入；runtime(2)恰在600秒处被超时终止。依据本次实测，将集成workflow的runtime／visual两处导入预算从600调至900秒，与已有共享合同的900秒预算一致；保留每遍有限超时和严格退出／日志检查。其他运行回归及整项任务时限保持原值。

同轮Windows发布任务也明确在import.log阶段超时600秒，未到达导出／启动验收。发布工具新增独立的--import-timeout，默认900秒，原--timeout默认600秒仍控制导出和玩家验证；macOS导入预算原本即为900秒。新增回归验证默认及自定义导入预算不会传给导出，并拒绝无穷、非数或非正的两类超时参数。
