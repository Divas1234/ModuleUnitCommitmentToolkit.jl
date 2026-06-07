const fs = require('fs'); // File system module
const plotly = require('plotly')('username', 'apiKey');

// Specify the file path
const filePath = '/Users/yuanyiping/Documents/GitHub/unit_commitment_code/eacharea_BFSFR/out/trick_draw_3dsurface/.data/reformed_result.txt'; // Replace with your file path

// Read the file
fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
        console.error('Error reading the file:', err);
        return;
    }

    // Split data into rows and columns
    const lines = data.trim().split('\n');
    const parsedData = lines.map(line => line.split('\t').map(Number)); // Convert strings to numbers

    // Prepare X, Y, and Z data for the surface plot
    const x = parsedData[0].slice(1); // X-axis (skip first column)
    const y = parsedData.slice(1).map(row => row[0]); // Y-axis (first column of each row)
    const z = parsedData.slice(1).map(row => row.slice(1)); // Z-axis (matrix of data)

    // Create the surface plot
    const surfacePlot = {
        x: x,
        y: y,
        z: z,
        type: 'surface'
    };

    const layout = {
        title: 'Surface Plot',
        scene: {
            xaxis: { title: 'X-axis' },
            yaxis: { title: 'Y-axis' },
            zaxis: { title: 'Z-axis' }
        }
    };

    // Plot using Plotly
    const graphOptions = { filename: 'surface-plot', fileopt: 'overwrite' };
    plotly.plot([surfacePlot], graphOptions, (err, msg) => {
        if (err) {
            console.error('Error plotting:', err);
        } else {
            console.log('Plot URL:', msg.url);
        }
    });
});