#!/usr/bin/env python3
import argparse
from pathlib import Path


TEMPLATE = """import os
from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).parent
SHOTS = ROOT / "test-shots"
SHOTS.mkdir(exist_ok=True)
PAGES = {pages}


def capture(page, path: str, name: str) -> None:
    page.goto((ROOT / path).resolve().as_uri(), wait_until="load")
    page.screenshot(path=str(SHOTS / name), full_page=True)


with sync_playwright() as p:
    launch_kwargs = {{"headless": True}}
    executable_path = os.environ.get("PLAYWRIGHT_BROWSER_PATH")
    if executable_path:
        launch_kwargs["executable_path"] = executable_path

    browser = p.chromium.launch(**launch_kwargs)
    desktop = browser.new_page(viewport={{"width": 1440, "height": 1400}}, locale="ru-RU")
    for path in PAGES:
        stem = Path(path).stem
        capture(desktop, path, f"{{stem}}.png")

    mobile = browser.new_page(
        viewport={{"width": 390, "height": 844}},
        is_mobile=True,
        has_touch=True,
        locale="ru-RU",
    )
    for path in PAGES:
        stem = Path(path).stem
        capture(mobile, path, f"{{stem}}-mobile.png")

    browser.close()
"""


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a static Playwright smoke test.")
    parser.add_argument("--output", required=True, help="Path to write smoke_test.py")
    parser.add_argument("--paths", nargs="+", required=True, help="HTML files to capture")
    args = parser.parse_args()

    output = Path(args.output)
    output.write_text(TEMPLATE.format(pages=repr(args.paths)), encoding="utf-8")
    print(f"Wrote {output}")


if __name__ == "__main__":
    main()
