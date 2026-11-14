# M02 山脊竞速　A　依赖 G02、G03

来源：2026-11-07 架构审查及其最后实施记录。整理日期：2026-11-14。下列待办保留原状态；实施前核对本包源码与工作区，不以历史检查代替本次验收。

[共享 G01–G03 任务](../../../protocols/godot_party_default_protocol/doc/godot_party_default_protocol_development.md) · [包说明](gp_car_racing_guide.md)


包：`gp_car_racing`。定位：[scripts/main.gd](../scripts/main.gd) 的 `_setup_inputs()`；[scripts/arcade_car.gd](../scripts/arcade_car.gd) 的 `_ready()`、`_physics_process()`；`scenes/car.tscn`。

- [x] 用正式输入注入替换运行时添加/删除全局动作，保留 F6 独立操作；处理原 Esc 暂停和框架菜单，菜单打开时车辆不能继续采纳驾驶输入。
- [ ] 四个车轮 pivot 目前仍在 `_ready()` 查名、创建并 reparent；保存到车辆子场景并显式引用。固定发动机播放器入场景/音频组件。
- [ ] 清理本包业务代码中的 `:=` 和未声明类型；场景专用类型只在确有共享需求时保留全局 `class_name`。
- [ ] 港区场景和赛道 Curve3D 保留。`harbor_scenery.gd` 的生成器当前未发现正式场景引用，先确认作者工具用途再归档/删除，不能把它误报为当前重复生成。道路网格根据曲线生成继续保留。

验证：四轮转向/滚动、漂移和氮气、赛道曲线编辑、三圈成绩、退出后无遗留输入/发动机声。

## 人工验收待办

保留自 2026-11-05 场景审查，后续记录未明确关闭的人工事项：完整三圈与驾驶手感待人工验收。
