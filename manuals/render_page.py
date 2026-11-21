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
            # Reserve the final printed page for the left-hand slot.
            has_facing_page = 0 < page_index and page_index + 1 < page_count - 1
            indices = [page_index, page_index + 1] if has_facing_page else [page_index]
            dimensions = [document.get_page_size(index) for index in indices]
            widest = max(width for width, _ in dimensions)
            tallest = max(height for _, height in dimensions)
            scale = min(3.0, 950 / widest, 1500 / tallest)
            pages = [render_bitmap(document, index, scale) for index in indices]
            gutter = 8
            column = max(page.width for page in pages)
            spread = Image.new("RGBA", (column * 2 + gutter, max(page.height for page in pages)))
            first_x = column + gutter if page_index == 0 else column - pages[0].width
            spread.paste(pages[0], (first_x, 0))
            if has_facing_page:
                spread.paste(pages[1], (column + gutter, 0))
            spread.save(output.with_suffix(".png"))
            return {
                "pages": page_count, "last_index": indices[-1],
                "first_x": first_x, "first_width": pages[0].width, "first_height": pages[0].height,
            }
    except (ValueError, OSError, RuntimeError, pypdfium2.PdfiumError):
        return {"error": "Could not read this PDF. Check that it opens and is not password-protected."}


if __name__ == "__main__":
    source, index, prefix = sys.argv[1:]
    destination = Path(prefix)
    result = render(source, int(index), destination)
    destination.with_suffix(".json").write_text(json.dumps(result), encoding="utf-8")
