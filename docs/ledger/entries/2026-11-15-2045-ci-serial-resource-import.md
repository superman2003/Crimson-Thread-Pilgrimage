## 2026-11-15：串行导入素材，规避CI冷导入堆损坏（T03 CI稳定性）

PR663的Godot integration regressions运行43710191132中，runtime(1)在资源导入97%、最后进度标签NotoSansSC.ttf附近，以SIGABRT／exit=-6退出，原始日志为“double free or corruption (fasttop)”，没有Godot脚本错误。该分片后续全部运行回归成功，另两分片、视觉、原生合同和三平台发布构建均成功；此前的LFS拉取问题已由35b6535e6修复，不重复归因于素材缺失。

在project.godot设置editor/import/use_multiple_threads=false，采用Godot4.6.1支持的串行资源导入路径，规避并发导入风险。这是针对引擎导入阶段的防护；现有日志没有符号化堆栈，不能断言具体字体或分配器调用就是根因。保留run_godot_import.py原有两遍导入、非零退出、ERROR／SCRIPT ERROR与超时拒绝，不新增重试、忽略失败或修改workflow。

依据：[4.6.1导入实现](https://github.com/godotengine/godot/blob/4.6.1-stable/editor/file_system/editor_file_system.cpp)、[ProjectSettings说明](https://github.com/godotengine/godot/blob/4.6.1-stable/doc/classes/ProjectSettings.xml)及[上游并发导入问题](https://github.com/godotengine/godot/issues/109374)。Windows Godot4.6.1以三张正式图集和两套实际字体作隔离冷、暖两遍导入，均通过；原生探针确认串行设置已生效。这是设置生效与代表性导入验证，不冒充原Linux崩溃复现；完整项目结果由本次CI确认。

集成workflow6项与LFS workflow5项、合同lint和台账格式通过。本地import工具的11项Unix进程夹具在Windows按既有条件跳过；合同工具16项中5项受Windows符号链接权限限制，未计为通过，LinuxCI继续执行完整检查。
