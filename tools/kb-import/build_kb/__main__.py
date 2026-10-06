"""Command line for the condition builder: `python3 -m build_kb` from tools/kb-import."""

from __future__ import annotations

import argparse

from . import __doc__ as USAGE
from .assemble import build


def main() -> None:
    parser = argparse.ArgumentParser(prog="python3 -m build_kb", description=USAGE,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--limit", type=int, help="only build the first N conditions (for trials)")
    parser.add_argument("--mesh-year", type=int, default=2026)
    args = parser.parse_args()
    build(args.limit, args.mesh_year)


if __name__ == "__main__":
    main()
