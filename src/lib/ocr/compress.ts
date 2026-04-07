/**
 * Compress, resize, and auto-orient an image before sending to OCR.
 * Accepts a data-URL or object-URL string, returns a JPEG data-URL.
 *
 * Max dimension: 2048px  Quality: 0.92
 * Higher resolution is critical for medical documents with small printed text.
 * Gemini tokenises images at 258 tokens/tile regardless, so larger = better accuracy.
 *
 * Auto-orientation:
 * - Reads EXIF orientation from JPEG images and applies the correct rotation.
 * - This fixes sideways photos from phone cameras (common with document scans).
 * - Modern browsers handle EXIF in <img> tags but canvas.drawImage() does NOT,
 *   so we must apply the rotation manually before drawing to canvas.
 */

/**
 * Read EXIF orientation tag from a JPEG data-URL or base64 string.
 * Returns 1-8 (EXIF orientation) or 1 if not found / not JPEG.
 */
function readExifOrientation(dataUrl: string): number {
  try {
    // Extract base64 portion
    const base64Match = dataUrl.match(/base64,([\s\S]+)/);
    if (!base64Match) return 1;

    const binary = atob(base64Match[1].slice(0, 200000)); // Only need first ~150KB for EXIF
    const view = new DataView(new ArrayBuffer(binary.length));
    for (let i = 0; i < binary.length; i++) view.setUint8(i, binary.charCodeAt(i));

    // Check JPEG SOI marker
    if (view.getUint16(0) !== 0xFFD8) return 1;

    let offset = 2;
    while (offset < view.byteLength - 2) {
      const marker = view.getUint16(offset);
      offset += 2;

      if (marker === 0xFFE1) {
        // APP1 — EXIF
        const length = view.getUint16(offset);
        const exifStart = offset + 2;

        // Check "Exif\0\0"
        if (
          view.getUint8(exifStart) !== 0x45 || // E
          view.getUint8(exifStart + 1) !== 0x78 || // x
          view.getUint8(exifStart + 2) !== 0x69 || // i
          view.getUint8(exifStart + 3) !== 0x66  // f
        ) {
          offset += length;
          continue;
        }

        const tiffStart = exifStart + 6;
        const littleEndian = view.getUint16(tiffStart) === 0x4949;
        const ifdOffset = view.getUint32(tiffStart + 4, littleEndian);
        const ifdStart = tiffStart + ifdOffset;
        const entries = view.getUint16(ifdStart, littleEndian);

        for (let i = 0; i < entries; i++) {
          const entryOffset = ifdStart + 2 + i * 12;
          if (entryOffset + 12 > view.byteLength) break;
          const tag = view.getUint16(entryOffset, littleEndian);
          if (tag === 0x0112) {
            // Orientation tag
            return view.getUint16(entryOffset + 8, littleEndian);
          }
        }
        return 1;
      } else if ((marker & 0xFF00) === 0xFF00) {
        // Skip other markers
        offset += view.getUint16(offset);
      } else {
        break;
      }
    }
  } catch {
    // EXIF parsing failed — return default orientation
  }
  return 1;
}

/**
 * Apply EXIF orientation transform to canvas context.
 * Standard EXIF orientation values 1-8.
 */
function applyExifOrientation(
  ctx: CanvasRenderingContext2D,
  orientation: number,
  width: number,
  height: number
) {
  switch (orientation) {
    case 2: ctx.transform(-1, 0, 0, 1, width, 0); break;              // flip H
    case 3: ctx.transform(-1, 0, 0, -1, width, height); break;        // rotate 180
    case 4: ctx.transform(1, 0, 0, -1, 0, height); break;             // flip V
    case 5: ctx.transform(0, 1, 1, 0, 0, 0); break;                   // transpose
    case 6: ctx.transform(0, 1, -1, 0, height, 0); break;             // rotate 90 CW
    case 7: ctx.transform(0, -1, -1, 0, height, width); break;        // transverse
    case 8: ctx.transform(0, -1, 1, 0, 0, width); break;              // rotate 90 CCW
    default: break; // orientation 1 = normal, no transform needed
  }
}

export function compressImage(
  src: string,
  maxDim = 2048,
  quality = 0.92
): Promise<string> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      const orientation = readExifOrientation(src);
      const swapDimensions = orientation >= 5 && orientation <= 8;

      let { width, height } = img;

      // Scale down to maxDim
      if (width > maxDim || height > maxDim) {
        if (width > height) {
          height = Math.round((height * maxDim) / width);
          width = maxDim;
        } else {
          width = Math.round((width * maxDim) / height);
          height = maxDim;
        }
      }

      // Canvas dimensions account for rotation
      const canvasW = swapDimensions ? height : width;
      const canvasH = swapDimensions ? width : height;

      const canvas = document.createElement("canvas");
      canvas.width = canvasW;
      canvas.height = canvasH;
      const ctx = canvas.getContext("2d")!;

      applyExifOrientation(ctx, orientation, canvasW, canvasH);
      ctx.drawImage(img, 0, 0, width, height);

      resolve(canvas.toDataURL("image/jpeg", quality));
    };
    img.onerror = () => reject(new Error("Failed to load image for compression"));
    img.src = src;
  });
}
