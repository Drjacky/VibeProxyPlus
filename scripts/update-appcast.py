#!/usr/bin/env python3
"""Insert or replace a release item in a Sparkle appcast.

Usage:
  update-appcast.py --appcast appcast.xml --version 14.10.0 --build 840 \
      --url https://.../VibeProxyPlus-arm64-unsigned.zip --length 12345 \
      --signature BASE64 [--notes-file notes.md] [--min-system 13.0]

Items are kept newest first. An existing item with the same
sparkle:shortVersionString is replaced, so re-running for a tag is idempotent.
Release notes are embedded as Markdown (sparkle:format="markdown", Sparkle >= 2.7).
"""

import argparse
import re
import sys
from email.utils import formatdate
from xml.sax.saxutils import escape, quoteattr


def build_item(args, notes):
    description = ""
    if notes.strip():
        safe_notes = notes.replace("]]>", "]]]]><![CDATA[>")
        description = (
            '      <description sparkle:format="markdown"><![CDATA[\n'
            f"{safe_notes.rstrip()}\n"
            "]]></description>\n"
        )
    return (
        "    <item>\n"
        f"      <title>Version {escape(args.version)}</title>\n"
        f"      <sparkle:version>{escape(args.build)}</sparkle:version>\n"
        f"      <sparkle:shortVersionString>{escape(args.version)}</sparkle:shortVersionString>\n"
        f"      <sparkle:minimumSystemVersion>{escape(args.min_system)}</sparkle:minimumSystemVersion>\n"
        f"      <pubDate>{formatdate(usegmt=True)}</pubDate>\n"
        f"{description}"
        f"      <enclosure url={quoteattr(args.url)}\n"
        '                 type="application/octet-stream"\n'
        f"                 sparkle:edSignature={quoteattr(args.signature)}\n"
        f'                 length="{int(args.length)}"/>\n'
        "    </item>\n"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--appcast", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--length", required=True)
    parser.add_argument("--signature", required=True)
    parser.add_argument("--notes-file")
    parser.add_argument("--min-system", default="13.0")
    args = parser.parse_args()

    notes = ""
    if args.notes_file:
        with open(args.notes_file, encoding="utf-8") as f:
            notes = f.read()

    with open(args.appcast, encoding="utf-8") as f:
        xml = f.read()

    version_tag = f"<sparkle:shortVersionString>{escape(args.version)}</sparkle:shortVersionString>"
    xml = re.sub(
        r"[ \t]*<item>(?:(?!</item>).)*?" + re.escape(version_tag) + r".*?</item>\n?",
        "",
        xml,
        flags=re.S,
    )

    item = build_item(args, notes)
    first_item = re.search(r"[ \t]*<item>", xml)
    if first_item:
        xml = xml[: first_item.start()] + item + xml[first_item.start():]
    elif "</channel>" in xml:
        idx = xml.index("</channel>")
        line_start = xml.rfind("\n", 0, idx) + 1
        xml = xml[:line_start] + item + xml[line_start:]
    else:
        sys.exit(f"{args.appcast}: no <channel> element found")

    with open(args.appcast, "w", encoding="utf-8") as f:
        f.write(xml)


if __name__ == "__main__":
    main()
