# E05：八套构筑方案、旧名称与确认管理

新增八批第 2 批，接在 U06 改键批之后。后端支持八套方案，旧 UI 只枚举三个固定名称；现在列出所有现存名称，并用未占用的默认名称补到八行，旧存档自定义名称也能恢复。

覆盖已有方案和删除方案需要确认，默认焦点是“保留原方案”；确认时重新检查页面／钟龛上下文。删除只移除指定方案，不改当前装备、次数或冷却。World 保存／删除都明确检查钟龛，并走已有持久事务；写盘失败恢复整份原方案。新建空方案仍可一键保存，恢复继续使用原条件／数值预览。

验证：六套 CPU 回归通过：build_system 105、build_slots_ui 44、build_transaction_runtime 34、input_settings_regression 91、save_product 45、save_recovery 35；完整 npm test、test:campaign 通过。新增测试覆盖全八行、旧名称、默认取消焦点、取消清理、离龛后确认拒绝、删除读写和注入失败回滚。夹具截图只在实际渲染器下截取，避免 Dummy 上无纹理报错，不跳过任何布局或输入断言。早期错误断言（弹窗焦点应读取 Window 自己的 viewport；损坏方案反例须在正常 roundtrip 前移除）已修正，原日志保留。

最终真实 llvmpipe GL 的 build_slots_ui 44 项也通过。首次显示环境缺 xkbcomp／libxkbfile，补齐隔离运行依赖后重跑，不把无法启动显示器算成游戏断言通过。

证据在 `artifacts/e05_loadout_management/`。这仍是定位组件与生产 World 的事务检查，不是自然获得多构筑或实体手柄体验；E05、T04 与全部46项最终验收保持 OPEN。
