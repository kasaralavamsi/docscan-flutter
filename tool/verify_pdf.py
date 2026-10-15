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

corrected = pymupdf.open(root / 'corrected.pdf')
assert 'Receipt' in corrected[0].get_text()
assert 'Invoice' not in corrected[0].get_text()
assert 'café' not in corrected[0].get_text()  # Empty corrected word is omitted safely.
assert corrected[0].get_pixmap().samples == image_only[0].get_pixmap().samples
annotated = pymupdf.open(root / 'annotated.pdf')
without_ocr = pymupdf.open(root / 'annotated_without_ocr.pdf')
assert 'Approved café' in annotated[0].get_text()
assert 'Approved café' in without_ocr[0].get_text()
assert 'Invoice' not in without_ocr[0].get_text()
assert annotated[0].get_pixmap().samples == without_ocr[0].get_pixmap().samples
assert annotated[0].get_pixmap().samples != image_only[0].get_pixmap().samples
# Both marker and freehand path must be visible, on the intended part of the page.
pix = annotated[0].get_pixmap()
def pixel(x, y):
    return pix.pixel(round(x * pix.width), round(y * pix.height))[:3]
r, g, b = pixel(.3, .5)
assert r > 230 and g > 220 and b < 200, (r, g, b)
blue = [d for d in annotated[0].get_drawings() if d['type'] == 's']
assert blue and blue[0]['rect'].y0 > annotated[0].rect.height * .65
assert blue[0]['rect'].y1 < annotated[0].rect.height * .85
print('Editing checks passed: OCR corrections, visible text, highlight and signature export.')
