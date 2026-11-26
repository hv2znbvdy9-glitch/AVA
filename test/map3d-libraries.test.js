'use strict';

const assert = require('assert');
const {
	MAP3D_ARTICLE,
	MAP3D_LIBRARIES,
	map3dLibrariesData,
	map3dLibrariesReport,
} = require('../src/map3d-libraries');

assert.strictEqual(MAP3D_ARTICLE.author, 'Hamza Musa');
assert.strictEqual(MAP3D_ARTICLE.published, '2025-09-23');
assert.ok(MAP3D_ARTICLE.url.startsWith('https://medevel.com/'));

assert.strictEqual(MAP3D_LIBRARIES.length, 16);
const names = MAP3D_LIBRARIES.map((library) => library.name);
assert.strictEqual(new Set(names).size, 16, 'library names must be unique');

for (const library of MAP3D_LIBRARIES) {
	assert.ok(typeof library.name === 'string' && library.name.length > 0);
	assert.ok(typeof library.language === 'string' && library.language.length > 0);
	assert.ok(typeof library.runtime === 'string' && library.runtime.length > 0);
	assert.ok(typeof library.focus === 'string' && library.focus.length > 0);
	assert.ok(/^https:\/\/github\.com\//.test(library.repository), `${library.name} repository URL`);
}

assert.throws(() => {
	MAP3D_LIBRARIES.push({name: 'mutated'});
}, TypeError);
assert.throws(() => {
	MAP3D_LIBRARIES[0].name = 'mutated';
}, TypeError);

const data = map3dLibrariesData();
assert.deepStrictEqual(data.article, MAP3D_ARTICLE);
assert.strictEqual(data.libraries.length, 16);
data.libraries[0].name = 'mutated';
assert.strictEqual(MAP3D_LIBRARIES[0].name, 'CesiumJS', 'data() must return copies');

assert.ok(names.includes('CesiumJS'));
assert.ok(names.includes('deck.gl'));
assert.ok(names.includes('MapLibre'));
assert.ok(names.includes('OctoMap'));
assert.ok(names.includes('azul'));
assert.ok(names.includes('Martin'));

const report = map3dLibrariesReport();
assert.ok(report.includes('Hamza Musa'));
assert.ok(report.includes('ohne Netzwerk- oder Systemaktionen'));
for (const library of MAP3D_LIBRARIES) {
	assert.ok(report.includes(library.name), `report missing ${library.name}`);
	assert.ok(report.includes(library.repository), `report missing ${library.name} repository`);
}
assert.ok(report.includes('16. Martin'));

const {map3dLibrariesReport: viaIndex} = require('../src/index');
assert.strictEqual(typeof viaIndex, 'function');

console.log('3D map libraries reference tests passed');
