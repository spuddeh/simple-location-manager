"""Generate the stickied-comment BBCode for the Nexus page from nexus_changelog.md.

The Nexus comment box holds 5000 characters and the history no longer fits in one, so the
output is split across numbered posts. Splitting by hand is what let a post cross the limit
twice, unnoticed until Nexus rejected it, so the count is computed rather than estimated.

    python scripts/build-stickied-bbcode.py

Reads and rewrites the "## Stickied Comment BBCode" section of nexus_changelog.md in place;
everything above that section is left alone. Run it after ANY edit to a changelog entry.

Two rules are encoded here rather than left to whoever is editing:

  KEEP_TOGETHER  1.6.0 was never uploaded, so it ships with 1.7.0 and both belong in the
                 newest post. Without this the packer would put 1.6.0 in the second post and
                 a reader who went 1.5.0 -> 1.7.0 would never see it.

  PACK           Packing stops at 4500, not 5000. A post that fits exactly today is one
                 wording tweak away from not fitting, and the limit is only discovered at
                 posting time.

Preset releases (1.0.0joker and friends) are excluded: they track their own history and have
never appeared in this comment.
"""

import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
CHANGELOG = os.path.join(HERE, os.pardir, "nexus_changelog.md")

LIMIT = 5000
PACK = 4500
KEEP_TOGETHER = 2

HEADER = "[color=#ffff00][size=5][b]- Changes -[/b][/size][/color]\n\n"
CONT = "[i](Continued - older versions)[/i]\n\n"
MARKER = "\n---\n## Stickied Comment BBCode"

SKIP = {"1.0.0joker", "1.0.0kp", "1.0.0apartments"}


def read_sections(body):
    """Every version section, newest first, as (version, [bullet, ...])."""
    sections = []
    for m in re.finditer(r"^### (.+?)\n(.*?)(?=^### |\Z)", body, re.S | re.M):
        title, rest = m.group(1).strip(), m.group(2)
        unreleased = re.match(r"\[Unreleased - v(.+)\]$", title)
        version = unreleased.group(1) if unreleased else title
        if version in SKIP:
            continue
        bullets = [ln[2:].strip() for ln in rest.splitlines() if ln.startswith("- ")]
        if bullets:
            sections.append((version, bullets))
    return sections


def block(version, bullets, spoiler):
    """One version's BBCode. A [*] item carries no closing tag - that is the Nexus dialect."""
    items = "".join("[*]%s\n" % b for b in bullets)
    inner = "[list]%s[/list]" % items
    if spoiler:
        inner = "[spoiler]%s[/spoiler]" % inner
    return "[b][size=3]Version %s[/size][/b]\n%s\n" % (version, inner)


def pack(blocks):
    comments, cur = [], HEADER
    for i, blk in enumerate(blocks):
        forced = i < KEEP_TOGETHER
        if not forced and len(cur) + len(blk) > PACK and cur not in (HEADER, HEADER + CONT):
            comments.append(cur.rstrip() + "\n")
            cur = HEADER + CONT
        cur += blk
    comments.append(cur.rstrip() + "\n")
    return comments


def main():
    s = io.open(CHANGELOG, encoding="utf-8").read()
    sections = read_sections(s.split("\n---\n## Notes")[0])

    # Newest expanded, everything older behind a spoiler.
    blocks = [block(v, b, i > 0) for i, (v, b) in enumerate(sections)]
    for (v, _), blk in zip(sections, blocks):
        print("   block %-12s %5d chars" % (v, len(blk)))

    comments = pack(blocks)

    out = [MARKER + "\n"]
    if len(comments) > 1:
        out.append(
            "\nThe history no longer fits one Nexus comment (5000 char limit), so it is %d posts. "
            "Post the last one first and work back, so the newest sits at the top of the thread.\n"
            % len(comments)
        )

    failed = False
    for i, c in enumerate(comments):
        label = "Comment %d - current" % (i + 1) if i == 0 else "Comment %d - older versions" % (i + 1)
        out.append("\n### %s\n\n```\n%s```\n\n> Character count: %d / %d\n" % (label, c, len(c), LIMIT))
        status = "OK" if len(c) <= LIMIT else "OVER LIMIT"
        print("Comment %d: %5d / %d  %s" % (i + 1, len(c), LIMIT, status))
        failed = failed or len(c) > LIMIT

    if failed:
        raise SystemExit("a comment is over the %d character limit; nothing written" % LIMIT)

    io.open(CHANGELOG, "w", encoding="utf-8", newline="").write(s.split(MARKER)[0] + "".join(out))
    print("versions included:", ", ".join(v for v, _ in sections))
    print("written:", os.path.normpath(CHANGELOG))


if __name__ == "__main__":
    main()
