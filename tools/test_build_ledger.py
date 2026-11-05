"""Self-test for build_ledger: shipped files are valid and render; planted
mistakes are reported; entries render newest first."""
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_ledger as L


def main():
    failures = []

    def check(ok, label):
        if not ok:
            failures.append(label)

    check(not L.problems(), 'shipped docs/ledger files are valid: %s' % L.problems()[:3])
    # PRs add entries without regenerating; main's ledger workflow rebuilds it.
    check(L.render().startswith('# '), 'the shipped files render')

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / 'ledger'
        shutil.copytree(L.LEDGER_DIR, root)
        entries = root / 'entries'
        (entries / '2099-01-02-0930-u01-sample.md').write_text('## 2099-01-02：较新的条目（U01）\n\n正文。\n', encoding='utf-8')
        (entries / '2099-01-02-0800-u01-earlier.md').write_text('## 2099-01-02：同日较早的条目（U01）\n\n正文。\n', encoding='utf-8')
        check(not L.problems(root), 'well-formed new entries are accepted')
        text = L.render(root)
        newer, earlier = text.find('较新的条目'), text.find('同日较早的条目')
        check(0 < newer < earlier, 'entries render newest first, by date then time')
        check(text.find('## 任务状态') < newer, 'the status table comes before the entries')

        bad = [
            ('2099-01-03-u01.md', '## 2099-01-03：缺时间\n', 'named YYYY-MM-DD-HHMM'),
            ('2099-01-03-0900-U01.md', '## 2099-01-03：大写主题\n', 'named YYYY-MM-DD-HHMM'),
            ('2099-01-03-0901-a.md', '没有标题\n', 'must start with a "## " heading'),
            ('2099-01-03-0902-b.md', '## 2099-01-04：日期不符\n', 'heading date differs'),
            ('2099-01-03-0903-c.md', '## 2099-01-03：一\n\n## 2099-01-03：二\n', 'more than one'),
            ('2099-01-03-0904-d.md', '## 2099-01-03：改表\n\n| U01 | x | y |\n', 'edits a status row'),
        ]
        for name, body, expected in bad:
            path = entries / name
            path.write_text(body, encoding='utf-8')
            check(any(expected in p for p in L.problems(root)), f'{name} is rejected ({expected})')
            path.unlink()
        row = root / 'status' / 'U01.md'
        original = row.read_text(encoding='utf-8')
        row.write_text('| U02 | wrong id | x |\n', encoding='utf-8')
        check(any('U01.md must hold' in p for p in L.problems(root)), 'a status file with the wrong task id is rejected')
        row.write_text(original + original, encoding='utf-8')
        check(any('U01.md must hold' in p for p in L.problems(root)), 'a status file with two rows is rejected')
        row.unlink()
        check(any('status row U01 is missing' in p for p in L.problems(root)), 'a missing task row is reported')

    if failures:
        for label in failures:
            print('FAIL', label)
        return 1
    print('build_ledger self-test OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
