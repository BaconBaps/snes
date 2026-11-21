"""Render a local manual page without launching a browser or blocking Godot."""
import json
from pathlib import Path
import sys


def render(path, page_index, output):
    try:
        import pypdfium2
        from PIL import Image  # noqa: F401
    except ImportError:
        return {"error": "Install PDF support: python -m pip install pypdfium2 Pillow"}
    try:
        with pypdfium2.PdfDocument(path) as document:
            page_count = len(document)
            if not 0 <= page_index < page_count:
                return {"error": "This page is unavailable."}
            page = document[page_index]
            try:
                scale = min(3.0, 1500 / max(page.get_width(), page.get_height()))
                bitmap = page.render(scale=scale)
                try:
                    bitmap.to_pil().save(output.with_suffix(".png"))
                finally:
                    bitmap.close()
            finally:
                page.close()
        return {"pages": page_count}
    except (ValueError, OSError, RuntimeError, pypdfium2.PdfiumError):
        return {"error": "Could not read this PDF. Check that it opens and is not password-protected."}


if __name__ == "__main__":
    source, index, prefix = sys.argv[1:]
    destination = Path(prefix)
    result = render(source, int(index), destination)
    destination.with_suffix(".json").write_text(json.dumps(result), encoding="utf-8")
