'use strict';

// Reference metadata for the open-source 3D map and globe libraries surveyed
// in the MEDevel.com article (Hamza Musa, 23 Sep 2025). This module is a
// curated reading list only: it integrates no third-party code, adds no
// dependencies, and performs no network or system actions.

const MAP3D_ARTICLE = Object.freeze({
	title: '16 Open-source Library and Frameworks to Build 3D Maps and 3D Globe!',
	author: 'Hamza Musa',
	published: '2025-09-23',
	url: 'https://medevel.com/16-open-source-library-frameworks-to-build-3d-maps-and-3d-globe/',
});

const MAP3D_LIBRARIES = Object.freeze([
	Object.freeze({
		name: 'CesiumJS',
		repository: 'https://github.com/CesiumGS/cesium',
		language: 'JavaScript',
		runtime: 'browser (WebGL)',
		focus: '3D globes and 2D maps; dynamic streaming, 3D terrain and imagery, GeoJSON/KML/CZML/glTF',
	}),
	Object.freeze({
		name: 'deck.gl',
		repository: 'https://github.com/visgl/deck.gl',
		language: 'JavaScript/TypeScript',
		runtime: 'browser (WebGL2/WebGPU)',
		focus: 'GPU-powered large-scale layered visualizations with 64-bit GPU precision; React compatible',
	}),
	Object.freeze({
		name: 'Kepler.gl',
		repository: 'https://github.com/keplergl/kepler.gl',
		language: 'JavaScript',
		runtime: 'browser (WebGL, built on deck.gl)',
		focus: 'No-code geospatial analysis of large datasets; embeddable React toolbox',
	}),
	Object.freeze({
		name: 'maprayJS',
		repository: 'https://github.com/sony/mapray-js',
		language: 'JavaScript',
		runtime: 'browser (WebGL)',
		focus: 'Interactive high-quality 3D globes and digital twins',
	}),
	Object.freeze({
		name: 'MapLibre',
		repository: 'https://github.com/maplibre',
		language: 'TypeScript (GL JS), C++ (Native)',
		runtime: 'browser and embedded (OpenGL/Metal/Vulkan)',
		focus: 'GPU-accelerated vector maps; style specification; Martin vector tiles from PostGIS/MBTiles',
	}),
	Object.freeze({
		name: 'OpenGlobus',
		repository: 'https://github.com/openglobus/openglobus',
		language: 'TypeScript/JavaScript',
		runtime: 'browser (WebGL)',
		focus: 'Interactive 3D maps from planet to small scale; terrain, imagery layers, measurement tools',
	}),
	Object.freeze({
		name: 'Tangram',
		repository: 'https://github.com/tangrams/tangram',
		language: 'JavaScript',
		runtime: 'browser (WebGL, Leaflet plugin)',
		focus: '2D/3D rendering of GeoJSON, TopoJSON and vector tiles',
	}),
	Object.freeze({
		name: 'map3d',
		repository: 'https://github.com/cartesiancs/map3d',
		language: 'JavaScript (React-Three-Fiber)',
		runtime: 'browser',
		focus: 'City 3D maps with buildings and roads; GLB export (MIT)',
	}),
	Object.freeze({
		name: 'Tangram ES',
		repository: 'https://github.com/tangrams/tangram-es',
		language: 'C++',
		runtime: 'Android, iOS, macOS, Linux, Raspberry Pi, Windows (OpenGL ES)',
		focus: 'Embedded real-time 2D/3D vector map rendering on resource-constrained devices',
	}),
	Object.freeze({
		name: 'TerriaJS',
		repository: 'https://github.com/TerriaJS/terriajs',
		language: 'JavaScript/TypeScript',
		runtime: 'browser (Cesium 3D, Leaflet 2D fallback)',
		focus: 'Web-based geospatial explorers; thousands of layers, 3D Tiles, time-enabled data, shareable URLs',
	}),
	Object.freeze({
		name: 'GemPy',
		repository: 'https://github.com/gempy-project/gempy',
		language: 'Python',
		runtime: 'desktop/Jupyter (GPU-accelerated)',
		focus: 'Implicit 3D structural geological modeling with probabilistic/Bayesian inference',
	}),
	Object.freeze({
		name: 'osgEarth',
		repository: 'https://github.com/gwaldron/osgearth',
		language: 'C++',
		runtime: 'desktop and embedded (OpenSceneGraph, GDAL)',
		focus: 'Geospatially accurate 3D terrain and map rendering for GIS tools and simulations',
	}),
	Object.freeze({
		name: 'OctoMap',
		repository: 'https://github.com/OctoMap/octomap',
		language: 'C++',
		runtime: 'robotics/embedded',
		focus: 'Octree-based 3D occupancy grid mapping with probabilistic sensor fusion for SLAM',
	}),
	Object.freeze({
		name: 'Ascend Maps',
		repository: 'https://github.com/styluslabs/maps',
		language: 'C++ (Tangram NG based)',
		runtime: 'Android, iOS, Windows, Linux',
		focus: 'Cross-platform app with 3D terrain, offline maps, track recording, OpenStreetMap vector tiles',
	}),
	Object.freeze({
		name: 'azul',
		repository: 'https://github.com/tudelft3d/azul',
		language: 'Swift',
		runtime: 'macOS 13+ (Apple Silicon and Intel)',
		focus: '3D city model viewer for CityGML, CityJSON, IndoorGML, OBJ, OFF, POLY (GPLv3)',
	}),
	Object.freeze({
		name: 'Martin',
		repository: 'https://github.com/maplibre/martin',
		language: 'Rust',
		runtime: 'server',
		focus: 'High-speed vector tile generation from PostGIS and MBTiles (part of the MapLibre ecosystem)',
	}),
]);

function map3dLibrariesData() {
	return {
		article: {...MAP3D_ARTICLE},
		libraries: MAP3D_LIBRARIES.map((library) => ({...library})),
	};
}

function map3dLibrariesReport() {
	const lines = [
		'Open-Source-Bibliotheken für 3D-Karten und 3D-Globen (Referenzliste)',
		'',
		`Quelle: ${MAP3D_ARTICLE.title}`,
		`Autor: ${MAP3D_ARTICLE.author}, ${MAP3D_ARTICLE.published}`,
		MAP3D_ARTICLE.url,
		'',
		'Hinweis: reine Metadaten ohne eingebundenen Fremdcode, ohne Abhängigkeiten',
		'und ohne Netzwerk- oder Systemaktionen.',
		'',
	];
	MAP3D_LIBRARIES.forEach((library, index) => {
		lines.push(`${index + 1}. ${library.name} (${library.language}, ${library.runtime})`);
		lines.push(`   ${library.focus}`);
		lines.push(`   ${library.repository}`);
	});
	return lines.join('\n');
}

module.exports = {
	MAP3D_ARTICLE,
	MAP3D_LIBRARIES,
	map3dLibrariesData,
	map3dLibrariesReport,
};
