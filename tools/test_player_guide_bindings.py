"""T05: the release README (docs/RELEASE_PLAYER_GUIDE.md) lists the real default
bindings. Defaults are read from the scripts that register them; each action's
keyboard/mouse keys must appear in the guide clause (split at ，；。（）) that
names the action, and each gamepad button or stick in the gamepad clause that
names it, so swapping two keys within one bullet also fails. A changed default
that is not reflected in the guide (or in EXPECT below) fails."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'godot' / 'scripts'
GUIDE = ROOT / 'docs' / 'RELEASE_PLAYER_GUIDE.md'

KEY_TEXT = {'KEY_LEFT': '左右方向键', 'KEY_RIGHT': '左右方向键', 'KEY_UP': '上下方向键', 'KEY_DOWN': '上下方向键',
            'KEY_SPACE': '空格', 'KEY_SHIFT': 'Shift', 'KEY_TAB': 'Tab', 'KEY_ESCAPE': 'Esc',
            'MOUSE_BUTTON_LEFT': '鼠标左键', 'MOUSE_BUTTON_RIGHT': '鼠标右键'}
JOY_TEXT = {'JOY_BUTTON_A': 'A', 'JOY_BUTTON_B': 'B', 'JOY_BUTTON_X': 'X', 'JOY_BUTTON_Y': 'Y',
            'JOY_BUTTON_LEFT_SHOULDER': 'LB', 'JOY_BUTTON_RIGHT_SHOULDER': 'RB',
            'JOY_AXIS_TRIGGER_LEFT': 'LT', 'JOY_AXIS_TRIGGER_RIGHT': 'RT',
            'JOY_BUTTON_DPAD_LEFT': '十字键 ←', 'JOY_BUTTON_DPAD_RIGHT': '十字键 →',
            'JOY_BUTTON_DPAD_UP': '十字键 ↑', 'JOY_BUTTON_DPAD_DOWN': '十字键 ↓',
            'JOY_BUTTON_START': 'Start', 'JOY_BUTTON_BACK': 'Back',
            'JOY_BUTTON_LEFT_STICK': 'L3', 'JOY_BUTTON_RIGHT_STICK': 'R3',
            'JOY_AXIS_LEFT_X': '左摇杆', 'JOY_AXIS_LEFT_Y': '左摇杆'}
CLAUSE = re.compile(r'[，；。（）]')
# action: (label on its keyboard line, label after its button on the gamepad line)
EXPECT = {
    'move_left': ('移动', '移动'), 'move_right': ('移动', '移动'),
    'aim_up': ('上下瞄准', '瞄准'), 'aim_down': ('上下瞄准', '瞄准'),
    'jump': ('跳跃', '跳跃'), 'dash': ('冲刺', '冲刺'),
    'attack': ('攻击', '攻击'), 'heal': ('疗伤', '疗伤'),
    'interact': ('交互', '交互'), 'inventory': ('行囊', '行囊'), 'map': ('地图', '地图'),
    'build_menu': ('构筑', '构筑'), 'audio_settings': ('设置', None), 'close_overlay': ('关闭界面', '关闭界面'),
    'skill_1': ('施放', '技能'), 'skill_cycle': ('切换技能', '切换技能'),
    'tool_cast': ('使用', '使用战具'), 'tool_cycle': ('切换战具', '切换战具'),
    'hook': ('钩索', '钩索'),
    'bell_guard': ('钟壳格挡', '钟壳格挡'), 'lantern_phase': ('灯影相位', '灯影相位'), 'crown_resonance': ('王冠共鸣', '王冠共鸣'),
}


def defaults():
    keys, joys = {}, {}
    def add(table, action, token):
        table.setdefault(action, set()).add(token)
    player = (SCRIPTS / 'player_controller.gd').read_text(encoding='utf-8')
    for action, body in re.findall(r'_bind_(?:key|mouse)\("(\w+)", \[([^\]]*)\]\)', player):
        for token in re.findall(r'(?:KEY|MOUSE_BUTTON)_\w+', body):
            add(keys, action, token)
    for action, token in re.findall(r'_bind_joy\("(\w+)", (JOY_BUTTON_\w+)\)', player):
        add(joys, action, token)
    for action, token in re.findall(r'_bind_joy_axis\("(\w+)", (JOY_AXIS_\w+),', player):
        add(joys, action, token)
    level = (SCRIPTS / 'main_level.gd').read_text(encoding='utf-8')
    for action, key, joy in re.findall(r'"(\w+)": \[(KEY_\w+), (JOY_\w+)\]', level):
        add(keys, action, key)
        add(joys, action, joy)
    settings = re.search(r'func _bind_audio_settings_key\(\).*?physical_keycode = (KEY_\w+)', level, re.S)
    add(keys, 'audio_settings', settings.group(1))
    shortcut = (SCRIPTS / 'build_shortcut_input.gd').read_text(encoding='utf-8')
    add(keys, 'build_menu', re.search(r'physical_keycode = (KEY_\w+)', shortcut).group(1))
    add(joys, 'build_menu', re.search(r'button_index = (JOY_BUTTON_\w+)', shortcut).group(1))
    ui = (SCRIPTS / 'pilgrimage_interface.gd').read_text(encoding='utf-8')
    for action, joy in re.findall(r'\["(\w+)",(JOY_BUTTON_\w+)\]', ui):
        if not action.startswith('ui_'):
            add(joys, action, joy)
    return keys, joys


def key_text(token):
    return KEY_TEXT.get(token, token.removeprefix('KEY_'))


def has_token(clause, token):
    # Latin key names must stand alone: "E" is not the E of "Esc".
    if token.isascii():
        return re.search(rf'(?<![A-Za-z0-9]){re.escape(token)}(?![A-Za-z0-9])', clause) is not None
    return token in clause


def clauses(line):
    return [part for part in CLAUSE.split(line) if part.strip()]


def main():
    failures = []
    keys, joys = defaults()
    text = GUIDE.read_text(encoding='utf-8')
    section = text[text.index('## 操作和设置'):text.index('## 保存与问题报告')]
    bullets = [line for line in section.splitlines() if line.startswith('- ')]
    pad = next((line for line in bullets if line.startswith('- 手柄：')), '')
    board = [line for line in bullets if line is not pad]
    for action in sorted(set(keys) | set(joys)):
        if action not in EXPECT:
            failures.append(f'{action} has a default binding the guide test does not know; add it to the guide and EXPECT')
    board_clauses = [part for line in board for part in clauses(line)]
    pad_clauses = clauses(pad)
    for action, (label, pad_label) in EXPECT.items():
        wanted = sorted({key_text(t) for t in keys.get(action, set())})
        if not wanted:
            failures.append(f'{action}: no default keyboard/mouse binding found in the scripts')
        elif not any(label in part and all(has_token(part, token) for token in wanted) for part in board_clauses):
            failures.append(f'{action}: no guide clause names "{label}" with its default keys {wanted}')
        for token in sorted(joys.get(action, set())):
            text = JOY_TEXT.get(token, token)
            if pad_label is None:
                failures.append(f'{action}: gamepad default {token} needs a gamepad label in EXPECT')
            elif not any(pad_label in part and has_token(part, text) for part in pad_clauses):
                failures.append(f'{action}: no gamepad clause names "{pad_label}" with "{text}"')
    if 'F9' not in section:
        failures.append('the guide no longer warns that F9 opens a new journey')
    for line in failures:
        print('PLAYER_GUIDE_BINDINGS_FAIL ' + line)
    if failures:
        return 1
    print('PLAYER_GUIDE_BINDINGS_OK actions=%d keyboard=%d gamepad=%d' % (len(EXPECT), sum(len(v) for v in keys.values()), sum(len(v) for v in joys.values())))
    return 0


if __name__ == '__main__':
    sys.exit(main())
