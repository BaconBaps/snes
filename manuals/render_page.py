"""Render a local manual spread without launching a browser or blocking Godot."""
import json
from pathlib import Path
import sys


def render_bitmap(document, index, scale):
    page = document[index]
    try:
        bitmap = page.render(scale=scale)
        try:
            return bitmap.to_pil().convert("RGBA")
        finally:
            bitmap.close()
    finally:
        page.close()


def render(path, page_index, output):
    try:
        import pypdfium2
        from PIL import Image
    except ImportError:
        return {"error": "Install PDF support: python -m pip install pypdfium2 Pillow"}
    try:
        with pypdfium2.PdfDocument(path) as document:
            page_count = len(document)
            if not 0 <= page_index < page_count:
                return {"error": "This page is unavailable."}
            last_index = min(page_index + 1, page_count - 1)
            dimensions = [document.get_page_size(index) for index in range(page_index, last_index + 1)]
            total_width = sum(width for width, _ in dimensions)
            if len(dimensions) == 1:
                total_width *= 2
            tallest = max(height for _, height in dimensions)
            scale = min(3.0, 1900 / total_width, 1500 / tallest)
            left = render_bitmap(document, page_index, scale)
            right = render_bitmap(document, last_index, scale) if last_index > page_index else None
            gutter = 8
            right_width = right.width if right else left.width
            right_height = right.height if right else left.height
            spread = Image.new("RGBA", (left.width + gutter + right_width, max(left.height, right_height)))
            spread.paste(left, (0, 0))
            if right:
                spread.paste(right, (left.width + gutter, 0))
            spread.save(output.with_suffix(".png"))
            return {"pages": page_count, "left_width": left.width, "left_height": left.height}
    except (ValueError, OSError, RuntimeError, pypdfium2.PdfiumError):
        return {"error": "Could not read this PDF. Check that it opens and is not password-protected."}


if __name__ == "__main__":
    source, index, prefix = sys.argv[1:]
    destination = Path(prefix)
    result = render(source, int(index), destination)
    destination.with_suffix(".json").write_text(json.dumps(result), encoding="utf-8")
