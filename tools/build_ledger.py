"""Render docs/UPGRADE_TASK_LEDGER.md from docs/ledger/.

Each PR adds its own entry file, so parallel PRs no longer collide at the top
of one shared file:

  docs/ledger/header.md              title (rarely changes)
  docs/ledger/status/<ID>.md         one status-table row per task (46 files)
  docs/ledger/entries/YYYY-MM-DD-HHMM-<topic>.md
                                     one dated entry ("## YYYY-MM-DD：..."), newest first
  docs/ledger/archive.md             early free-form history, kept verbatim

The generated ledger is rebuilt on main by .github/workflows/ledger.yml; PRs
must not edit it by hand.

  python3 tools/build_ledger.py            write the ledger
  python3 tools/build_ledger.py --check    exit 1 if the ledger is stale
  python3 tools/build_ledger.py --validate only check docs/ledger/ (PR CI)
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEDGER_DIR = ROOT / 'docs' / 'ledger'
OUTPUT = ROOT / 'docs' / 'UPGRADE_TASK_LEDGER.md'
# Row order of the status table: the 46 task packages of the plan.
TASKS = ['W00', 'W01', 'W02', 'W03', 'W04', 'W05', 'A01', 'A02', 'C01', 'C02', 'C03', 'C04',
         'E01', 'E02', 'E03', 'E04', 'E05', 'B01', 'B02', 'B03', 'B04', 'G01', 'G02',
         'N01', 'N02', 'N03', 'N04', 'N05', 'U01', 'U02', 'U03', 'U04', 'U05', 'U06',
         'V01', 'V02', 'V03', 'V04', 'S01', 'S02', 'S03', 'T01', 'T02', 'T03', 'T04', 'T05']
ENTRY_NAME = re.compile(r'^(\d{4}-\d{2}-\d{2})-(\d{4})-[a-z0-9][a-z0-9-]*\.md$')
NOTICE = ('> 本文件由 `tools/build_ledger.py` 生成，请勿直接修改。新增记录：在 `docs/ledger/entries/` '
          '新建 `YYYY-MM-DD-HHMM-主题.md`；更新状态：改 `docs/ledger/status/<编号>.md`。'
          '说明见 [docs/ledger/README.md](ledger/README.md)。')


def problems(root=LEDGER_DIR):
    found = []
    if not (root / 'header.md').is_file():
        found.append('docs/ledger/header.md is missing')
    if not (root / 'archive.md').is_file():
        found.append('docs/ledger/archive.md is missing')
    status = root / 'status'
    for task in TASKS:
        path = status / f'{task}.md'
        if not path.is_file():
            found.append(f'status row {task} is missing')
            continue
        text = path.read_text(encoding='utf-8').strip('\n')
        if '\n' in text or not text.startswith(f'| {task} |') or text.count('|') < 4:
            found.append(f'{path.name} must hold exactly one table row "| {task} | 当前证据 | 下一验收交付 |"')
    for path in status.glob('*.md') if status.is_dir() else []:
        if path.stem not in TASKS:
            found.append(f'status/{path.name} is not one of the 46 tasks')
    entries = root / 'entries'
    for path in sorted(entries.iterdir()) if entries.is_dir() else []:
        match = ENTRY_NAME.match(path.name)
        if not match:
            found.append(f'entries/{path.name} must be named YYYY-MM-DD-HHMM-<topic>.md (lowercase topic)')
            continue
        text = path.read_text(encoding='utf-8')
        first = text.split('\n', 1)[0]
        if not first.startswith('## '):
            found.append(f'entries/{path.name} must start with a "## " heading')
        elif match.group(1) not in first:
            found.append(f'entries/{path.name}: heading date differs from the file name date')
        if re.search(r'(?m)^## ', text.split('\n', 1)[1] if '\n' in text else ''):
            found.append(f'entries/{path.name} holds more than one "## " entry')
        if re.search(r'(?m)^\| [A-Z]\d{2} \|', text):
            found.append(f'entries/{path.name} edits a status row; change docs/ledger/status/<ID>.md instead')
    return found


def render(root=LEDGER_DIR):
    header = (root / 'header.md').read_text(encoding='utf-8').strip('\n')
    rows = [(root / 'status' / f'{task}.md').read_text(encoding='utf-8').strip('\n') for task in TASKS]
    names = sorted((p.name for p in (root / 'entries').iterdir() if ENTRY_NAME.match(p.name)), reverse=True)
    entries = [(root / 'entries' / name).read_text(encoding='utf-8').strip('\n') for name in names]
    archive = (root / 'archive.md').read_text(encoding='utf-8').strip('\n')
    table = '\n'.join(['## 任务状态（46 项）', '', '| 编号 | 当前证据 / 状态 | 下一验收交付 |', '|---|---|---|'] + rows)
    return '\n\n'.join([header, NOTICE, table] + entries + [archive]) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--check', action='store_true', help='fail when the generated ledger is stale')
    parser.add_argument('--validate', action='store_true', help='only check the entry and status files')
    args = parser.parse_args()
    found = problems()
    if found:
        for line in found:
            print('LEDGER_ERROR ' + line)
        return 1
    if args.validate:
        print('LEDGER_FILES_OK')
        return 0
    text = render()
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_text(encoding='utf-8') != text:
            print('LEDGER_STALE run: python3 tools/build_ledger.py')
            return 1
        print('LEDGER_OK')
        return 0
    OUTPUT.write_text(text, encoding='utf-8')
    print(f'LEDGER_WRITTEN {OUTPUT.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
