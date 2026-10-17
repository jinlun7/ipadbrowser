"""PadBrowser Bookmark HTML Parser 离线状态机验证脚本。

用于独立测试与验证 Netscape Bookmark HTML 导入算法的层级栈与实体转义边界用例。
"""
import re
import sys
from urllib.parse import urlparse

ENTITIES = [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", '"'), ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " ")]


def decode_entities(text):
    for entity, plain in ENTITIES:
        text = text.replace(entity, plain)
    return text


def attribute(name, attributes):
    pattern = r"\b%s\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))" % name
    m = re.search(pattern, attributes, re.IGNORECASE)
    if not m:
        return None
    for group in (1, 2, 3):
        if m.group(group):
            return decode_entities(m.group(group))
    return None


def normalized_url(raw):
    trimmed = raw.strip()
    if not trimmed:
        return None
    scheme = urlparse(trimmed).scheme.lower()
    if scheme not in ("http", "https"):
        return None
    return trimmed


def strip_tags(text):
    return re.sub(r"<[^>]*>", "", text)


def import_netscape_html(text):
    bookmarks, folders = [], []
    folder_order = bookmark_order = invalid = 0
    stack = [None]                      # 栈底是根级
    pending_folder = None               # <H3> 声明的文件夹，等下一个 <DL> 才生效
    i = 0

    while i < len(text):
        open_angle = text.find("<", i)
        if open_angle == -1:
            break
        # 找标签名结束处：'>' 或空白
        j = open_angle + 1
        while j < len(text) and text[j] not in "> \t\n\r":
            j += 1
        tag = text[open_angle + 1:j].upper()

        close_angle = text.find(">", j)
        if close_angle == -1:
            break
        attributes = text[j:close_angle]
        after = close_angle + 1

        if tag == "DL":
            stack.append(pending_folder)
            pending_folder = None
        elif tag == "/DL":
            if len(stack) > 1:
                stack.pop()
        elif tag == "H3":
            raw_title = text[after:]
            end = raw_title.find("<")
            name = decode_entities(
                strip_tags(raw_title if end == -1 else raw_title[:end])).strip()
            parent = stack[-1] if stack else None
            folders.append({"name": name or "未命名文件夹",
                            "parent": parent,
                            "order": folder_order})
            folder_order += 1
            pending_folder = len(folders) - 1        # 用下标当临时 id
        elif tag == "A":
            raw_title = text[after:]
            end = raw_title.find("<")
            title = decode_entities(
                strip_tags(raw_title if end == -1 else raw_title[:end])).strip()
            href = attribute("HREF", attributes)
            if not href or normalized_url(href) is None:
                invalid += 1
            else:
                bookmarks.append({"title": title or "书签",
                                  "url": normalized_url(href),
                                  "folder": stack[-1] if stack else None,
                                  "order": bookmark_order})
                bookmark_order += 1

        i = after

    return bookmarks, folders, invalid


def resolve_paths(bookmarks, folders):
    """把临时下标还原成人类可读的路径。"""
    names = [f["name"] for f in folders]
    parents = [f["parent"] for f in folders]

    def path(idx):
        parts, guard = [], 0
        while idx is not None and guard < 64:
            parts.append(names[idx])
            idx = parents[idx]
            guard += 1
        return " / ".join(reversed(parts)) or "(根级)"

    return bookmarks, [path(i) for i in range(len(folders))]


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8") as f:
        text = f.read()

    bms, fds, invalid = import_netscape_html(text)
    bms, fds = resolve_paths(bms, fds)

    print(f"文件夹 {len(fds)} 个：")
    for path in fds:
        print("  -", path)
    print(f"\n书签 {len(bms)} 条：")
    for b in bms:
        print(f"  - [{fds[b['folder']] if b['folder'] is not None else '(根级)'}] {b['title']} -> {b['url']}")
    print(f"\n跳过的无效链接：{invalid}")
