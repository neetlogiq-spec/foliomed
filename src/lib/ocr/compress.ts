/**
 * Compress and resize an image before sending to OCR.
 * Accepts a data-URL or object-URL string, returns a JPEG data-URL.
 *
 * Max dimension: 2048px  Quality: 0.92
 * Higher resolution is critical for medical documents with small printed text.
 * Gemini tokenises images at 258 tokens/tile regardless, so larger = better accuracy.
 */
export function compressImage(
  src: string,
  maxDim = 2048,
  quality = 0.92
): Promise<string> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      let { width, height } = img;
      if (width > maxDim || height > maxDim) {
        if (width > height) {
          height = Math.round((height * maxDim) / width);
          width = maxDim;
        } else {
          width = Math.round((width * maxDim) / height);
          height = maxDim;
        }
      }
      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      canvas.getContext("2d")!.drawImage(img, 0, 0, width, height);
      resolve(canvas.toDataURL("image/jpeg", quality));
    };
    img.onerror = () => reject(new Error("Failed to load image for compression"));
    img.src = src;
  });
}
