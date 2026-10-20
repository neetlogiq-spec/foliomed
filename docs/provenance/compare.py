"""Line-containment provenance comparison: FolioMed vs original Wardly.

retained_pct = share of a file's code lines that also appear, as a
*distinctive* line (in at most two original files), in the original.
"""
import csv, os, re, subprocess, sys

orig_root, new_root, out_csv = sys.argv[1], sys.argv[2], sys.argv[3]
TEXT_EXT = {'.dart', '.kt', '.kts', '.swift', '.java', '.gradle', '.xml', '.plist', '.yaml', '.yml',
            '.json', '.html', '.css', '.js', '.ts', '.sql', '.md', '.sh', '.properties', '.entitlements',
            '.xcconfig', '.pbxproj', '.storyboard', '.cmake', '.txt', '.cc', '.cpp', '.h'}
SKIP_PREFIX = ('functions/node_modules/', 'graphify-out/', 'build/')

def tracked(root):
    out = subprocess.run(['git', '-C', root, 'ls-files'], capture_output=True, text=True).stdout.split('\n')
    return [p for p in out if p and not p.startswith(SKIP_PREFIX)]

def norm_lines(path):
    try:
        txt = open(path, encoding='utf-8', errors='ignore').read()
    except Exception:
        return []
    txt = re.sub(r'wardly', 'foliomed', txt, flags=re.I)
    lines = []
    for l in txt.split('\n'):
        s = re.sub(r'\s+', ' ', l).strip()
        # ignore trivial lines that match anywhere
        if len(s) < 12 or s in ('});', '),', '],', '];', '} else {', 'return;'):
            continue
        if s.startswith(('//', '///', '*', '/*', 'import ', 'export ', '#')):
            continue
        lines.append(s)
    return lines

orig_files = tracked(orig_root)
orig_lines = {p: norm_lines(os.path.join(orig_root, p)) for p in orig_files
              if os.path.splitext(p)[1] in TEXT_EXT}
orig_sets = {p: set(v) for p, v in orig_lines.items()}
# A line counts as evidence of copying only if it's distinctive: lines that
# appear in 3+ original files are framework idiom (e.g. `mainAxisSize:
# MainAxisSize.min,`) that any Flutter app contains.
_freq = {}
for _set in orig_sets.values():
    for _l in _set:
        _freq[_l] = _freq.get(_l, 0) + 1
DISTINCT = {l for l, n in _freq.items() if n <= 2}
orig_sets = {p: v & DISTINCT for p, v in orig_sets.items()}
all_orig_lines = set().union(*orig_sets.values()) if orig_sets else set()
orig_by_norm_path = {re.sub('wardly', 'foliomed', p, flags=re.I): p for p in orig_files}
orig_binary = {}
for p in orig_files:
    if os.path.splitext(p)[1] not in TEXT_EXT:
        try:
            orig_binary[open(os.path.join(orig_root, p), 'rb').read()] = p
        except Exception:
            pass

rows = []
for p in tracked(new_root):
    full = os.path.join(new_root, p)
    ext = os.path.splitext(p)[1]
    if ext not in TEXT_EXT:
        try:
            data = open(full, 'rb').read()
        except Exception:
            continue
        twin = orig_binary.get(data)
        rows.append([p, twin or '', 'binary', '', '100' if twin else '0',
                     'identical binary' if twin else 'new/changed binary'])
        continue
    lines = norm_lines(full)
    if not lines:
        rows.append([p, orig_by_norm_path.get(p, ''), 'text', 0, '', 'trivial/empty'])
        continue
    counterpart = orig_by_norm_path.get(p)
    if counterpart is None or counterpart not in orig_sets:
        # moved/renamed file: best counterpart by containment
        best, best_score = '', 0.0
        for op, os_ in orig_sets.items():
            if not os_ or os.path.splitext(op)[1] != ext:
                continue
            sc = sum(1 for l in lines if l in os_) / len(lines)
            if sc > best_score:
                best, best_score = op, sc
        counterpart = best if best_score >= 0.3 else ''
    same = sum(1 for l in lines if l in orig_sets.get(counterpart, set())) / len(lines) if counterpart else 0.0
    anywhere = sum(1 for l in lines if l in all_orig_lines) / len(lines)
    pct = round(max(same, anywhere) * 100)
    cls = ('original (largely retained)' if pct >= 70 else
           'modified original' if pct >= 35 else
           'mostly rewritten' if pct >= 10 else 'new')
    rows.append([p, counterpart, 'text', len(lines), pct, cls])

with open(out_csv, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['foliomed_path', 'original_counterpart', 'kind', 'code_lines', 'retained_pct', 'class'])
    w.writerows(sorted(rows))
print('files', len(rows))
