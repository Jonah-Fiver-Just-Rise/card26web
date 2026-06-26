const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'src', 'App.jsx');
const content = fs.readFileSync(filePath, 'utf8');
const lines = content.split('\n');

const darkColors = ['#111118', '#0d0d12', '#2a2a3e', '#1e1e2e', '#0d0d18', '#161622', '#1a1a28', '#12121e', '#0c0c14', '#1a1200', '#1a0808'];

lines.forEach((line, idx) => {
  const matched = darkColors.filter(c => line.includes(c));
  if (matched.length > 0) {
    console.log(`Line ${idx + 1}: [Matches: ${matched.join(', ')}] -> ${line.trim()}`);
  }
});
