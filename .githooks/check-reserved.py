#!/usr/bin/env python3
"""Fails when a BrightScript reserved word is used as a variable, loop variable or parameter name, or when a
file spells one m. field two ways (m.PV and m.pv): names ignore case, so they're the same field and one
overwrites the other (m.PV, a preview's [x, y, w, h], crashed pvClose() as Pick a version's m.pv).

The Roku compiler rejects these ("Syntax Error. Builtin function call expected", &h9d, for `pos`), but only
on the device, after a sideload. This catches them at build time. Run by build-zip.sh; safe to run by hand:
    python3 .githooks/check-reserved.py            (checks components/ and source/)
    python3 .githooks/check-reserved.py file.brs   (checks the files given)

Reserved words: Roku's "Reserved words" reference, plus the keywords added since (mod, try/catch/throw,
continue). Field names after a dot (t.type) and associative-array keys ({ type: "x" }) are allowed and not
flagged. Names of built-in functions that aren't reserved (right, mid, len...) compile fine as variables.
"""
import re
import sys
from pathlib import Path

RESERVED = {
    "and", "box", "createobject", "dim", "each", "else", "elseif", "end", "endfunction", "endif", "endsub",
    "endwhile", "eval", "exit", "exitwhile", "false", "for", "function", "getglobalaa",
    "getlastruncompileerror", "getlastrunruntimeerror", "goto", "if", "invalid", "let", "line_num", "m",
    "next", "not", "objfun", "or", "pos", "print", "rem", "return", "run", "step", "stop", "sub", "tab",
    "then", "to", "true", "type", "while",
    # newer keywords
    "mod", "try", "catch", "endtry", "throw", "continue",
}


IDENT = r"[A-Za-z_][A-Za-z0-9_]*"
ASSIGN = re.compile(rf"^\s*({IDENT})\s*(?:[-+*/\\]|<<|>>)?=(?!=)")
FOR_EACH = re.compile(rf"\bfor\s+each\s+({IDENT})\s+in\b", re.I)
FOR_TO = re.compile(rf"\bfor\s+({IDENT})\s*=", re.I)
DEF = re.compile(rf"^\s*(?:function|sub)\s+{IDENT}\s*\((.*)\)", re.I)
PARAM = re.compile(rf"^\s*({IDENT})\b")


def strip(line):
    """The line without string literals ("" is an escaped quote) and without its comment (' or rem)."""
    out, i, n = [], 0, len(line)
    while i < n:
        c = line[i]
        if c == '"':
            j = i + 1
            while j < n:
                if line[j] == '"':
                    if j + 1 < n and line[j + 1] == '"':
                        j += 2
                        continue
                    break
                j += 1
            out.append('""')
            i = j + 1
            continue
        if c == "'":
            break
        out.append(c)
        i += 1
    s = "".join(out)
    return re.split(r"(?i)(?:^|\s)rem(?:\s|$)", s, maxsplit=1)[0]


def names(code):
    """(name, what) for each name the line declares: assigned variables, loop variables, parameters."""
    found = []
    # several statements on one line: a = 1 : b = 2
    for stmt in code.split(":"):
        m = ASSIGN.match(stmt)
        if m and not re.match(r"(?i)\s*(if|else|elseif|while|for|return|print)\b", stmt):
            found.append((m.group(1), "variable"))
    found += [(m.group(1), "loop variable") for m in FOR_EACH.finditer(code)]
    found += [(m.group(1), "loop variable") for m in FOR_TO.finditer(code) if m.group(1).lower() != "each"]
    m = DEF.match(code)
    if m:
        for p in m.group(1).split(","):
            pm = PARAM.match(p)
            if pm:
                found.append((pm.group(1), "parameter"))
    return found


def check(path):
    errors = []
    spellings = {}          # m. field, lower case -> {spelling: first line}
    for no, raw in enumerate(Path(path).read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        code = strip(raw)
        for f in re.findall(rf"\bm\.({IDENT})", code):
            spellings.setdefault(f.lower(), {}).setdefault(f, no)
        for name, what in names(code):
            low = name.lower()
            where = f"{path}:{no}"
            if low in RESERVED:
                errors.append(f"{where}: reserved word '{name}' used as a {what} name")
    for forms in spellings.values():
        if len(forms) > 1:
            (a, la), (b, lb) = sorted(forms.items(), key=lambda x: x[1])[:2]
            errors.append(f"{path}:{lb}: m.{b} is the same field as m.{a} (line {la}): names ignore case")
    return errors


def main(argv):
    files = argv or sorted(str(p) for d in ("components", "source") for p in Path(d).rglob("*.brs"))
    errors = []
    for f in files:
        errors += check(f)
    for e in errors:
        print("error: " + e, file=sys.stderr)
    if errors:
        print(f"{len(errors)} BrightScript naming problem(s): rename them (see CLAUDE.local.md)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
