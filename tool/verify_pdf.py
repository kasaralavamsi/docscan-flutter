"""After flutter test: python -m pip install pymupdf && python tool/verify_pdf.py."""
from pathlib import Path
import pymupdf

root = Path('build/test_outputs')
searchable = pymupdf.open(root / 'searchable.pdf')
image_only = pymupdf.open(root / 'image_only.pdf')
assert len(searchable) == len(image_only) == 2
assert 'Invoice' in searchable[0].get_text()
assert 'café' in searchable[0].get_text()
assert not searchable[1].get_text().strip()
for index, (text_page, image_page) in enumerate(zip(searchable, image_only)):
    assert not image_page.get_text().strip()
    assert text_page.rect == image_page.rect
    assert text_page.get_pixmap().samples == image_page.get_pixmap().samples, \
        'The OCR layer must not alter the visible scan'
    if index == 0:
        assert text_page.rect.height > text_page.rect.width
        invoice = text_page.search_for('Invoice')[0]
        scale = 842 / 300
        assert abs(invoice.x0 - 20 * scale) < 2
        assert abs(invoice.y0 - 30 * scale) < 3
        assert abs(invoice.width - 60 * scale) < 3
    else:
        assert text_page.rect.width > text_page.rect.height
print('PDF checks passed: extraction, accents, blank page, geometry and invisible text.')
