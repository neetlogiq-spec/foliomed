"""Deeper provenance comparison of two Dart codebases (lib/).

1. Structural fingerprints (MOSS-style winnowing) over a normalised token
   stream: identifiers -> I, strings -> S, numbers -> N, comments dropped.
   Catches code that was copied and then renamed or reformatted.
   Calibrated against an unrelated Flutter corpus, because widget code has
   common shapes no matter who wrote it.
2. The same with real identifiers kept (stricter: copied code with names).
3. String literals: identical or near-identical user-facing text.
4. Identical declared class / function names.
"""
import difflib
import zlib
import os
import re
import sys
from collections import defaultdict

orig_root, new_root, control_root = sys.argv[1], sys.argv[2], sys.argv[3]

KEYWORDS = set("""abstract as assert async await break case catch class const continue covariant
default deferred do dynamic else enum export extends extension external factory false final finally
for get hide if implements import in interface is late library mixin new null on operator part
required rethrow return sealed set show static super switch sync this throw true try typedef var
void when while with yield""".split())

TOKEN = re.compile(r"""
    (?P<comment>//[^\n]*|/\*.*?\*/)
  | (?P<string>r?'''.*?'''|r?\"\"\".*?\"\"\"|r?'(?:\\.|[^'\\\n])*'|r?"(?:\\.|[^"\\\n])*")
  | (?P<number>\b\d+(?:\.\d+)?\b)
  | (?P<ident>[A-Za-z_$][A-Za-z0-9_$]*)
  | (?P<punct>[{}()\[\];,.:?=<>+\-*/%!&|^~@#]+)
""", re.S | re.X)


def dart_files(root):
    out = []
    for d, _, fs in os.walk(os.path.join(root, 'lib')):
        for f in fs:
            if f.endswith('.dart') and not f.endswith(('.g.dart', '.freezed.dart')):
                out.append(os.path.join(d, f))
    return out


def tokens(src, keep_names):
    src = re.sub('wardly', 'foliomed', src, flags=re.I)
    toks, strings = [], []
    for m in TOKEN.finditer(src):
        kind = m.lastgroup
        v = m.group(kind)
        if kind == 'comment':
            continue
        if kind == 'string':
            strings.append(v)
            toks.append('S')
        elif kind == 'number':
            toks.append('N')
        elif kind == 'ident':
            toks.append(v if (keep_names or v in KEYWORDS) else 'I')
        else:
            toks.append(v)
    return toks, strings


def fingerprints(toks, k, w):
    """Winnowing: hash every k-gram, keep the minimum of each window of w."""
    if len(toks) < k:
        return set()
    # Stable across runs (Python's hash() is randomised per process).
    hashes = [zlib.crc32(' '.join(toks[i:i + k]).encode()) for i in range(len(toks) - k + 1)]
    fp = set()
    for i in range(max(1, len(hashes) - w + 1)):
        fp.add(min(hashes[i:i + w]))
    return fp


def corpus(root, keep_names, k, w):
    per_file, everything = {}, set()
    for f in dart_files(root):
        t, _ = tokens(open(f, errors='ignore').read(), keep_names)
        fp = fingerprints(t, k, w)
        per_file[f] = fp
        everything |= fp
    return per_file, everything


def score(new_files, other_all):
    """Share of each new file's fingerprints found anywhere in the other corpus."""
    return {f: (len(fp & other_all) / len(fp) if fp else 0.0) for f, fp in new_files.items()}


def report_structure(label, keep_names, k, w):
    new_fp, _ = corpus(new_root, keep_names, k, w)
    _, orig_all = corpus(orig_root, keep_names, k, w)
    _, ctrl_all = corpus(control_root, keep_names, k, w)
    vs_orig, vs_ctrl = score(new_fp, orig_all), score(new_fp, ctrl_all)
    sizes = {f: len(fp) for f, fp in new_fp.items()}
    tot = sum(sizes.values()) or 1
    w_orig = sum(vs_orig[f] * sizes[f] for f in sizes) / tot
    w_ctrl = sum(vs_ctrl[f] * sizes[f] for f in sizes) / tot
    print(f"\n== {label} (k={k}, window={w})")
    print(f"   shared with original Wardly : {w_orig * 100:5.1f}% of FolioMed fingerprints")
    print(f"   shared with unrelated Flutter code (baseline): {w_ctrl * 100:5.1f}%")
    flagged = sorted(
        ((vs_orig[f], vs_ctrl[f], f) for f in sizes if sizes[f] >= 10 and vs_orig[f] - vs_ctrl[f] >= 0.15),
        reverse=True)
    if flagged:
        print("   files sharing notably more with Wardly than with the baseline:")
        for o, c, f in flagged[:15]:
            print(f"     {o * 100:4.0f}% (baseline {c * 100:3.0f}%)  {os.path.relpath(f, new_root)}")
    else:
        print("   no file shares notably more with Wardly than with the baseline")


def norm_text(s):
    s = re.sub(r"^r?('''|\"\"\"|'|\")|('''|\"\"\"|'|\")$", '', s)
    s = re.sub(r'\$\{[^}]*\}|\$\w+', '_', s)
    s = re.sub(r'\\n|\\u[0-9a-fA-F]{4}', ' ', s)
    s = re.sub('wardly', 'foliomed', s, flags=re.I)
    return re.sub(r'\s+', ' ', s).strip().lower()


def ui_strings(root):
    out = defaultdict(set)
    for f in dart_files(root):
        _, strs = tokens(open(f, errors='ignore').read(), True)
        for s in strs:
            n = norm_text(s)
            # Ignore keys, paths, column names and short labels.
            if len(n) >= 18 and ' ' in n and not re.fullmatch(r'[a-z0-9_./:-]+', n):
                out[n].add(os.path.relpath(f, root))
    return out


def report_strings():
    new_s, orig_s = ui_strings(new_root), ui_strings(orig_root)
    exact = sorted(set(new_s) & set(orig_s))
    print(f"\n== Wording: {len(new_s)} FolioMed text strings (18+ chars) checked")
    print(f"   identical to a Wardly string: {len(exact)}")
    for s in exact:
        print(f"     \"{s}\"  ({', '.join(sorted(new_s[s]))})")
    orig_list = list(orig_s)
    near = []
    for s in new_s:
        if s in orig_s or len(s) < 25:
            continue
        best = difflib.get_close_matches(s, orig_list, n=1, cutoff=0.85)
        if best:
            near.append((s, best[0]))
    print(f"   near-identical (85%+ similar): {len(near)}")
    for s, o in near[:20]:
        print(f"     FolioMed: \"{s}\"\n     Wardly:   \"{o}\"")


def declared_names(root):
    names = set()
    for f in dart_files(root):
        src = open(f, errors='ignore').read()
        names |= set(re.findall(r'^\s*(?:abstract |final |sealed )*(?:class|enum|mixin|extension) (\w+)', src, re.M))
        names |= set(re.findall(r'^(?:Future<[^>]*>|void|String|Widget|bool|int|double)\s+(\w+)\s*\(', src, re.M))
    return names


def report_names():
    shared = sorted(declared_names(new_root) & declared_names(orig_root))
    print(f"\n== Declared class/function names shared with Wardly: {len(shared)}")
    print("   " + ", ".join(shared))


report_structure('Structure (names ignored)', keep_names=False, k=30, w=8)
report_structure('Structure with real names', keep_names=True, k=20, w=6)
report_strings()
report_names()
