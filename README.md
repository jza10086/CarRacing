# 山脊竞速 · RIDGELINE

一个 Godot 4.x 原生 3D low-poly 街机赛车原型：驾驶橙色跑车，在 **786 米的晴岭赛道完成三圈计时挑战**。

单人计时赛，无 AI 对手、无联网功能。重点是清晰的赛道、轻快可控的驾驶和完整的开始—比赛—结算流程，而不是拟真车辆模拟。

![实际游戏画面](docs/gameplay.png)

## 运行

1. 使用 **Godot 4.7.2** 打开 `project.godot`（本项目实测版本）。
2. 首次打开等待模型与字体导入完成。
3. 按 **F5** 运行主场景，点击「开始驾驶」或按 Enter。

使用 Compatibility / OpenGL 渲染器，无外部插件、依赖安装或下载步骤。也可直接运行：

```sh
godot --path .
```

代码采用 Godot 4.x API，但未宣称所有早期 4.x 版本均已验证。源码仓库不包含引擎二进制、导出包或 `.godot` 导入缓存。

## 操作

| 按键 | 功能 |
|---|---|
| W / ↑ | 加速 |
| S / ↓ | 刹车；接近停止后继续按住会倒车 |
| A D / ← → | 左右转向 |
| Space | 手刹，降低抓地力并减速 |
| R | 返回最近一个有效检查点，计时继续 |
| Esc | 暂停 / 继续；暂停菜单可重新开始 |
| Enter | 从标题或结算界面开始新一局 |

高速转弯请先松油门或刹车；进入草地会减速。护栏限制驶出赛道。复位不跳过检查点，也不补发圈数。

## 第一版内容

- 平滑闭合的柏油赛道、连续路面碰撞、双色路肩、护栏、指示牌、起终点、看台与林地山景。
- 实际导入的 Kenney 跑车 GLB，独立转向/旋转车轮、视觉车身侧倾。
- 自写 `CharacterBody3D` 街机控制器：加速、刹车、倒车、速度相关转向、抓地/手刹恢复及草地阻力。
- 跟随镜头、速度相关视野、前方观察与障碍遮挡检测。
- 三秒起步倒计时；12 个有序、单向检查门；单圈/总计时、三圈结算和重新开始。
- 本地三圈最佳成绩保存在 `user://records.cfg`。QA 驾驶脚本不会写入成绩。
- 简洁中文 HUD、赛道小地图、暂停菜单和原创合成引擎声。

## 验证

```sh
# 导入 + 规则与真实物理测试（使用隔离的临时 user:// 目录）
GODOT_BIN=/path/to/godot tests/run_tests.sh

# 真正通过加速/刹车/转向 Input action 驾驶三圈，不移动坐标、不改圈数
/path/to/godot --headless --path . --fixed-fps 60 --script res://tests/drive_laps.gd

# 有可用桌面时，保存真实渲染的标题、驾驶、弯道、结算及短动画帧
/path/to/godot --path . --script res://tests/drive_laps.gd -- --capture-dir=/absolute/output/path
```

测试范围和实际结果见 [docs/TESTING.md](docs/TESTING.md)。脚本测试不等于所有 GPU/操作系统的硬件兼容性测试。云端原生画面在 Mesa llvmpipe 软件渲染器上验证；其帧率不代表用户独立 GPU 表现。

## 结构

- `scripts/arcade_car.gd`：车辆物理和模型动画。
- `scripts/track_world.gd`：原创建模的赛道、碰撞和场景布置。
- `scripts/race_rules.gd`：与画面解耦的计圈规则。
- `scripts/main.gd`：比赛流程、镜头及本地纪录。
- `scripts/race_hud.gd`：中文界面。
- `tests/`：针对性测试和正常输入驾驶验证。

## 美术、参考与许可

先研究 Godot 官方车辆/角色文档，以及 Truck Town、Godot Recipes、Godot Easy Vehicle Physics，再编写本项目的小型街机控制器；没有直接导入大型车辆框架。外观参考 low-poly 公路赛车的清晰轮廓和克制 UI。

程序代码 MIT；Kenney 模型/贴图 CC0；重命名 Noto Sans CJK 字体子集 SIL OFL 1.1。详见 [ASSET_CREDITS.md](ASSET_CREDITS.md) 与各资源目录的许可证。
