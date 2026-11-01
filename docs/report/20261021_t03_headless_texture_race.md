# T03：headless 下后台纹理加载改为就地执行，消除 Dummy 渲染器的 RID 竞争

PR #176 的 Windows 发布候选在导出包 headless 回访启动时报出三条引擎错误：`Initializing already initialized RID`、`Parameter "mem" is null`、`Parameter "t" is null`（`texture_2d_initialize`）。代码相同的前后两次运行都通过，属于偶发问题，与该 PR 无关。

原因在 Godot 4.6.1：headless 使用 Dummy 渲染器，它的纹理表 `RID_PtrOwner<DummyTexture>` 未开启线程安全（`THREAD_SAFE=false`），而 GL 驱动的纹理表是线程安全的。`BackgroundResourceJob`（共享图集与邻区预取）和 `PlayerArtWarmJob`（主角预读）在普通 Thread 上 `ResourceLoader.load` 纹理，与主线程同时分配纹理 RID 时可能损坏这张表。玩家正常运行用 GL，不受影响；会撞上的是导出包的 headless 启动检查，以及不带 `--software-gl` 的本地测试。测试运行器的 `--software-gl` 说明里早已写明它用于避开这一竞争，这次改为在生产代码里根除。

修复：两个任务在 `DisplayServer.get_name() == "headless"` 时于调用方线程就地加载，结果仍按原单一所有者约定在 `take()`/`shutdown()` 交出；headless 没有 GPU 上传可以并行，因此没有帧重叠损失。GL 下仍使用后台线程，行为不变。注意 headless 下 `RenderingServer.get_current_rendering_driver_name()` 返回的是配置值 `vulkan`，不能用来判断 Dummy。

新增默认套件 `background_texture_contention`：生产路径（两条共享图集请求、主角预读、主线程持续建纹理）各 24 轮，加上 40 轮“6 个任务各读一个小图标、主线程不让出地连续建纹理”的压力段；断言仅在非 headless 下离开主线程。临时去掉修复后，headless 连续 4 次全部失败，报错与 CI 相同；恢复修复后 headless 连续 5 次通过，零 ERROR（`threaded=false`），真实 GL 两次通过（`threaded=true`）。`background-resource-ownership` 工作流新增 headless 步骤运行该套件。

相关验证：`character_art_prewarm`（817 项，sync_loads=0）、`texture_request_exit`、`world_startup_budget` 在 headless 与真实 GL 下均通过，`npm test` 通过。三处原“必须离开主线程”的断言改为按渲染器判断：GL 下仍要求后台线程，headless 下要求就地加载。本批不涉及帧率、长时运行或发布包整体验收。
