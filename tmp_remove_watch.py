from pathlib import Path
import re

path = Path('GoFit.Ai - live Healthy.xcodeproj/project.pbxproj')
backup = path.with_suffix('.pbxproj.bak')
if not backup.exists():
    backup.write_text(path.read_text())

lines = path.read_text().splitlines(keepends=True)
remove_ids = {
    'C10001092F79B009009D604B',
    'C10001072F79B007009D604B',
    'C10001102F79B010009D604B',
    'C10001012F79B001009D604B',
    'B251BC982F6AE6390071BE5C',
    'C10001022F79B002009D604B',
    'C10001032F79B003009D604B',
    'C100010C2F79B00C009D604B',
}

# remove block by id

def remove_block(lines, start_idx):
    depth = 0
    i = start_idx
    while i < len(lines):
        line = lines[i]
        depth += line.count('{')
        depth -= line.count('}')
        if depth == 0:
            return start_idx, i + 1
        i += 1
    return start_idx, start_idx + 1

changed = False
for rid in list(remove_ids):
    idx = None
    for i, line in enumerate(lines):
        if rid in line and '= {' in line:
            idx = i
            break
    if idx is not None:
        s, e = remove_block(lines, idx)
        lines = lines[:s] + lines[e:]
        changed = True

# Remove references in array entries etc
pattern = re.compile(r'\b(' + '|'.join(remove_ids) + r')\b')
lines = [line for line in lines if not pattern.search(line)]

path.write_text(''.join(lines))
print('Updated project.pbxproj; watch target entries removed?', changed)
