import re


class LuaStripError(Exception):
    pass


def _long_bracket_level(s, i):
    if i >= len(s) or s[i] != "[":
        return None
    j = i + 1
    while j < len(s) and s[j] == "=":
        j += 1
    if j < len(s) and s[j] == "[":
        return j - i - 1, j + 1
    return None


def lua_tokens(src, name="?"):
    s = src.replace("\r\n", "\n").replace("\r", "\n")
    n = len(s)
    toks = []
    i = 0
    if s.startswith("#"):
        k = s.find("\n")
        k = n if k < 0 else k
        toks.append(("code", s[:k]))
        i = k
    buf = []

    def flush():
        if buf:
            toks.append(("code", "".join(buf)))
            buf.clear()

    while i < n:
        c = s[i]
        if c == "\n":
            flush()
            toks.append(("nl", "\n"))
            i += 1
            continue
        if c == "-" and s.startswith("--", i):
            flush()
            lb = _long_bracket_level(s, i + 2)
            if lb is not None:
                level, start = lb
                close = "]" + "=" * level + "]"
                k = s.find(close, start)
                if k < 0:
                    raise LuaStripError(f"{name}: comentario longo sem fim (offset {i})")
                toks.append(("comment", s[i:k + len(close)]))
                i = k + len(close)
            else:
                k = s.find("\n", i)
                k = n if k < 0 else k
                toks.append(("comment", s[i:k]))
                i = k
            continue
        if c in "\"'":
            j = i + 1
            while j < n:
                ch = s[j]
                if ch == "\\":
                    j += 2
                    continue
                if ch == c:
                    break
                if ch == "\n":
                    raise LuaStripError(f"{name}: string sem fim (offset {i})")
                j += 1
            if j >= n:
                raise LuaStripError(f"{name}: string sem fim no EOF (offset {i})")
            flush()
            toks.append(("str", s[i:j + 1]))
            i = j + 1
            continue
        if c == "[":
            lb = _long_bracket_level(s, i)
            if lb is not None:
                level, start = lb
                close = "]" + "=" * level + "]"
                k = s.find(close, start)
                if k < 0:
                    raise LuaStripError(f"{name}: string longa sem fim (offset {i})")
                flush()
                toks.append(("str", s[i:k + len(close)]))
                i = k + len(close)
                continue
        buf.append(c)
        i += 1
    flush()
    return toks


def _assemble(toks, keep_indent, drop_blank):
    lines = []
    cur = []
    had_comment = False
    had_code = False
    protected = False

    def finish(prot_end=False):
        nonlocal cur, had_comment, had_code, protected
        text = "".join(cur)
        if not prot_end:
            text = text.rstrip(" \t")
        if not keep_indent and not protected:
            text = text.lstrip(" \t")
        lines.append({"text": text, "comment": had_comment, "code": had_code,
                      "protected": protected or prot_end})
        cur = []
        had_comment = False
        had_code = False
        protected = False

    for kind, text in toks:
        if kind == "nl":
            finish()
        elif kind == "comment":
            had_comment = True
            nl = text.count("\n")
            if nl:
                if had_code:
                    cur.append(" ")
                if not drop_blank:
                    for _ in range(nl):
                        finish()
                        had_comment = True
            elif had_code and text.startswith("--[") and cur and not cur[-1].endswith((" ", "\t")):
                cur.append(" ")
        elif kind == "str":
            had_code = True
            parts = text.split("\n")
            if len(parts) == 1:
                cur.append(text)
            else:
                cur.append(parts[0])
                finish(prot_end=True)
                for mid in parts[1:-1]:
                    cur.append(mid)
                    protected = True
                    had_code = True
                    finish(prot_end=True)
                cur.append(parts[-1])
                protected = True
                had_code = True
        else:
            if text.strip():
                had_code = True
            cur.append(text)
    finish()
    return lines


def _render(lines, drop_blank):
    if not drop_blank:
        return "\n".join(l["text"] for l in lines)
    out = []
    for l in lines:
        if l["protected"] or l["code"]:
            out.append(l["text"])
            continue
        if l["comment"]:
            continue
        if out and out[-1] != "":
            out.append("")
    while out and out[0] == "":
        out.pop(0)
    while out and out[-1] == "":
        out.pop()
    return "\n".join(out) + ("\n" if out else "")


def strip_lua(src, name="?", keep_indent=False, drop_blank=False):
    toks = lua_tokens(src, name)
    lines = _assemble(toks, keep_indent, drop_blank)
    result = _render(lines, drop_blank)
    if not drop_blank:
        s = src.replace("\r\n", "\n").replace("\r", "\n")
        if s.count("\n") != result.count("\n"):
            raise LuaStripError(f"{name}: numero de linhas mudou "
                                f"({s.count(chr(10))} -> {result.count(chr(10))})")
    return result


def lua_comment_spans(src, name="?"):
    spans = []
    line = 1
    for kind, text in lua_tokens(src, name):
        if kind == "comment":
            spans.append((line, text))
        line += text.count("\n")
    return spans


def glsl_tokens(src, name="?"):
    s = src.replace("\r\n", "\n").replace("\r", "\n")
    n = len(s)
    toks = []
    i = 0
    buf = []

    def flush():
        if buf:
            toks.append(("code", "".join(buf)))
            buf.clear()

    while i < n:
        c = s[i]
        if c == "\n":
            flush()
            toks.append(("nl", "\n"))
            i += 1
            continue
        if c == "/" and s.startswith("//", i):
            flush()
            k = s.find("\n", i)
            k = n if k < 0 else k
            toks.append(("comment", s[i:k]))
            i = k
            continue
        if c == "/" and s.startswith("/*", i):
            flush()
            k = s.find("*/", i + 2)
            if k < 0:
                raise LuaStripError(f"{name}: comentario /* sem fim (offset {i})")
            toks.append(("comment", s[i:k + 2]))
            i = k + 2
            continue
        buf.append(c)
        i += 1
    flush()
    return toks


def strip_glsl(src, name="?"):
    toks = glsl_tokens(src, name)
    lines = _assemble(toks, True, True)
    return _render(lines, True)


_GLSL_TOKEN = re.compile(r"[A-Za-z_]\w*|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?|\S")


def glsl_token_stream(src, name="?"):
    out = []
    for kind, text in glsl_tokens(src, name):
        if kind == "code":
            out.extend(_GLSL_TOKEN.findall(text))
        elif kind == "nl":
            out.append("\n")
    merged = []
    for t in out:
        if t == "\n":
            if merged and merged[-1] != "\n":
                merged.append(t)
        else:
            merged.append(t)
    return merged


def glsl_comment_spans(src, name="?"):
    spans = []
    line = 1
    for kind, text in glsl_tokens(src, name):
        if kind == "comment":
            spans.append((line, text))
        line += text.count("\n")
    return spans
