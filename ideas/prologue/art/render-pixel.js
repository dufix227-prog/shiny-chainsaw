// Run in the browser on scene.svg; keeps text sharp while rasterizing only the illustration.
(async () => {
  const source = document.querySelector('svg');
  const imageOf = async (svg) => {
    const image = new Image();
    const url = URL.createObjectURL(new Blob([new XMLSerializer().serializeToString(svg)], { type: 'image/svg+xml' }));
    try {
      image.src = url;
      await image.decode();
      return image;
    } finally {
      URL.revokeObjectURL(url);
    }
  };
  const world = source.cloneNode(true);
  world.querySelector('#ui').remove();
  const raster = document.createElementNS('http://www.w3.org/1999/xhtml', 'canvas');
  raster.width = 426;
  raster.height = 266;
  raster.getContext('2d').drawImage(await imageOf(world), 0, 0, 426, 266);
  const overlay = source.cloneNode(true);
  overlay.querySelector('#world').remove();
  overlay.querySelector('#variant-label').textContent = 'ПРОБА 02 · МЕЛКИЙ ПИКСЕЛЬНЫЙ ШАГ';
  const output = document.createElementNS('http://www.w3.org/1999/xhtml', 'canvas');
  output.width = 1280;
  output.height = 800;
  const context = output.getContext('2d');
  context.imageSmoothingEnabled = false;
  context.drawImage(raster, 0, 0, 1280, 800);
  context.imageSmoothingEnabled = true;
  context.drawImage(await imageOf(overlay), 0, 0);
  const html = document.createElementNS('http://www.w3.org/1999/xhtml', 'html');
  const body = document.createElementNS('http://www.w3.org/1999/xhtml', 'body');
  body.style.margin = '0';
  body.append(output);
  html.append(body);
  document.replaceChild(html, document.documentElement);
  return 'Pixel mockup rendered: 1280×800; world only, no game behavior.';
})();
