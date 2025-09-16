<template>
  <div class="map-wrapper" @click="hideContextMenu">
    <div class="controls">
      <button @click="toggleLineMode">
        {{ drawingLine ? "Завершить рисование линии" : "Начать рисовать линию" }}
      </button>
      <button @click="saveConfig">Сохранить</button>
      <button @click="triggerFileInput">Загрузить</button>
      <input ref="fileInput" type="file" accept="application/json" @change="loadConfig" hidden/>
    </div>
    <div ref="mapRef" class="map-container"></div>

    <!-- Кастомное меню -->
    <div
      v-if="contextMenu.visible"
      class="context-menu"
      :style="{ top: contextMenu.y + 'px', left: contextMenu.x + 'px' }"
    >
      <template v-if="contextMenu.type === 'placemark'">
        <div class="context-item" @click.stop="renamePlacemark">✏️ Переименовать</div>
        <div class="context-item delete" @click.stop="deletePlacemark">🗑 Удалить</div>
      </template>
      <template v-else-if="contextMenu.type === 'polyline'">
        <div class="context-item delete" @click.stop="deletePolyline">🗑 Удалить линию</div>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, reactive } from "vue";
import geoConfigData from "@/assets/geoConfig.json";

const mapRef = ref(null);
const fileInput = ref(null);
let mapInstance = null;
let drawingLine = ref(false);
let lineCoords = [];
let polyline = null;

// Текущее состояние карты
let currentConfig = reactive({
  center: [0, 0],
  zoom: 1,
  placemarks: [],
  polylines: [],
});

// состояние контекстного меню
const contextMenu = reactive({
  visible: false,
  x: 0,
  y: 0,
  type: null,       // "placemark" | "polyline"
  object: null      // ymaps.Placemark | ymaps.Polyline
});

onMounted(() => {
  if (window.ymaps) {
    window.ymaps.ready(initMap);
  }
});

function initMap() {
  mapInstance = new window.ymaps.Map(mapRef.value, {
    center: currentConfig.center,
    zoom: currentConfig.zoom,
    controls: ["zoomControl", "typeSelector", "fullscreenControl"]
  });

  mapInstance.events.add("actionend", updateMapState);
  mapInstance.events.add("boundschange", updateMapState);

  // Клик по карте — ставим метку или рисуем линию
  mapInstance.events.add("click", function (e) {
    const coords = e.get("coords");

    if (drawingLine.value) {
      lineCoords.push(coords);
      updatePolyline();
    } else {
      const placeName = prompt("Введите название метки:", "Новая метка");
      addPlacemark(coords, placeName || "Без названия");
    }
  });

  restoreFromConfig(geoConfigData);
}

function updateMapState() {
  if (!mapInstance) return;
  currentConfig.center = mapInstance.getCenter();
  currentConfig.zoom = mapInstance.getZoom();
}

// --- Метки ---
function addPlacemark(coords, name) {
  const placemark = new window.ymaps.Placemark(
    coords,
    { balloonContent: name },
    { draggable: true }
  );

  placemark.events.add("contextmenu", e => {
    e.preventDefault();
    const pageCoords = e.get("domEvent").originalEvent;
    contextMenu.visible = true;
    contextMenu.x = pageCoords.pageX;
    contextMenu.y = pageCoords.pageY;
    contextMenu.type = "placemark";
    contextMenu.object = placemark;
  });

  mapInstance.geoObjects.add(placemark);
  currentConfig.placemarks.push({ coords, name });
}

function renamePlacemark() {
  if (!contextMenu.object) return;
  const oldName = contextMenu.object.properties.get("balloonContent");
  const newName = prompt("Введите новое название метки:", oldName);
  if (newName && newName.trim() !== "") {
    contextMenu.object.properties.set("balloonContent", newName);

    const coords = contextMenu.object.geometry.getCoordinates();
    const pm = currentConfig.placemarks.find(
      pm => pm.coords[0] === coords[0] && pm.coords[1] === coords[1] && pm.name === oldName
    );
    if (pm) pm.name = newName;
  }
  hideContextMenu();
}

function deletePlacemark() {
  if (!contextMenu.object) return;
  const coords = contextMenu.object.geometry.getCoordinates();
  const name = contextMenu.object.properties.get("balloonContent");

  mapInstance.geoObjects.remove(contextMenu.object);
  currentConfig.placemarks = currentConfig.placemarks.filter(
    pm => !(pm.coords[0] === coords[0] && pm.coords[1] === coords[1] && pm.name === name)
  );
  hideContextMenu();
}

// --- Линии ---
function addPolyline(coordsArray) {
  const pl = new window.ymaps.Polyline(coordsArray, {}, { strokeWidth: 4, strokeColor: "#ffdd00" });

  pl.events.add("contextmenu", e => {
    e.preventDefault();
    const pageCoords = e.get("domEvent").originalEvent;
    contextMenu.visible = true;
    contextMenu.x = pageCoords.pageX;
    contextMenu.y = pageCoords.pageY;
    contextMenu.type = "polyline";
    contextMenu.object = pl;
  });

  mapInstance.geoObjects.add(pl);
  currentConfig.polylines.push(coordsArray);
}

function deletePolyline() {
  if (!contextMenu.object) return;
  const coordsArray = contextMenu.object.geometry.getCoordinates();

  mapInstance.geoObjects.remove(contextMenu.object);
  currentConfig.polylines = currentConfig.polylines.filter(
    line => JSON.stringify(line) !== JSON.stringify(coordsArray)
  );
  hideContextMenu();
}

function toggleLineMode() {
  if (drawingLine.value) {
    if (lineCoords.length > 1) {
      addPolyline([...lineCoords]);
    }
    lineCoords = [];
    polyline = null;
  }
  drawingLine.value = !drawingLine.value;
}

function updatePolyline() {
  if (polyline) {
    mapInstance.geoObjects.remove(polyline);
  }
  polyline = new window.ymaps.Polyline(lineCoords, {}, { strokeWidth: 4, strokeColor: "#ffdd00" });
  mapInstance.geoObjects.add(polyline);
}

function hideContextMenu() {
  contextMenu.visible = false;
  contextMenu.object = null;
  contextMenu.type = null;
}

// --- Сохранение в geoConfig.json ---
function saveConfig() {
  updateMapState();
  const blob = new Blob([JSON.stringify(currentConfig, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "geoConfig.json";
  a.click();
  URL.revokeObjectURL(url);
}

// --- Загрузка geoConfig.json ---
function triggerFileInput() {
  fileInput.value.click();
}

function loadConfig(event) {
  const file = event.target.files[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = e => {
    try {
      const config = JSON.parse(e.target.result);
      restoreFromConfig(config);
      alert("Состояние карты восстановлено ✔️");
    } catch (err) {
      alert("Ошибка чтения файла ❗");
    }
  };
  reader.readAsText(file);
}

function restoreFromConfig(config) {
  mapInstance.geoObjects.removeAll();

  currentConfig.center = config.center;
  currentConfig.zoom = config.zoom;
  mapInstance.setCenter(config.center, config.zoom);

  currentConfig.placemarks.splice(0);
  currentConfig.polylines.splice(0);
  config.placemarks.forEach(pm => addPlacemark(pm.coords, pm.name));
  config.polylines.forEach(coordsArray => addPolyline(coordsArray));
}

onBeforeUnmount(() => {
  if (mapInstance) {
    mapInstance.destroy();
  }
});
</script>

<style scoped>
.map-wrapper {
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 10px;
  position: relative;
}

.controls {
  display: flex;
  justify-content: center;
  gap: 10px;
  margin-bottom: 5px;
}

button {
  padding: 8px 12px;
  border: none;
  background: #4caf50;
  color: white;
  border-radius: 4px;
  cursor: pointer;
}

button:hover {
  background: #45a049;
}

.map-container {
  width: 100%;
  height: 100%;
  border: 2px solid #ccc;
}

/* Кастомное меню */
.context-menu {
  position: absolute;
  background: white;
  border: 1px solid #ccc;
  border-radius: 4px;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
  min-width: 160px;
  z-index: 1000;
}

.context-item {
  padding: 8px 12px;
  cursor: pointer;
}

.context-item:hover {
  background: #f0f0f0;
}

.context-item.delete {
  color: #d32f2f;
}
</style>
