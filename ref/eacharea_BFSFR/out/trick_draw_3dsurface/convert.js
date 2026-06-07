const puppeteer = require('puppeteer');

(async () => {
    const browser = await puppeteer.launch();
    const page = await browser.newPage();
    await page.goto('file:///Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/trick_draw_3dsurface/unit_commitment_3d_bar_charts.html', {waitUntil: 'networkidle2'});

    // Save as PDF
    await page.pdf({path: 'unit_commitment_3d_bar_charts.pdf', format: 'A4'});

    // Save as SVG
    const svgContent = await page.evaluate(() => {
        const svgElement = document.querySelector('svg');
        return svgElement ? svgElement.outerHTML : '';
    });
    const fs = require('fs');
    fs.writeFileSync('unit_commitment_3d_bar_charts.svg', svgContent);

    await browser.close();
})();