<template>
  <div class="container">
    <!-- Левая панель: группы -->
    <aside class="sidebar">
      <h3>Группы объектов</h3>

      <!-- Создание группы -->
      <div class="group-create">
        <input v-model="newGroupId" placeholder="id группы (например, G1)" />
        <input v-model="newGroupUrl" placeholder="URL (необязательно)" />
        <button @click="createGroup">＋ Создать</button>
      </div>

      <ul class="group-list">
        <li
          v-for="g in groups"
          :key="g.id"
          :class="{ active: activeGroup === g.id }"
        >
          <div class="group-row">
            <div class="group-title" @click="selectGroup(g.id)" @dblclick="openGroupUrl(g)">
              <strong>{{ g.id }}</strong>
              <small v-if="g.url">🔗</small>
            </div>
            <div class="group-actions">
              <button @click="startEditGroup(g)">✏️</button>
              <button @click="deleteGroup(g.id)">🗑</button>
            </div>
          </div>

          <!-- Редактирование -->
          <div v-if="editingGroupId === g.id" class="group-edit">
            <input v-model="editGroupIdValue" placeholder="новый id"/>
            <input v-model="editGroupUrlValue" placeholder="новый URL (опц.)"/>
            <div class="edit-actions">
              <button @click="applyEditGroup">✔️ Сохранить</button>
              <button @click="cancelEditGroup">Отмена</button>
            </div>
          </div>
        </li>
      </ul>

      <p class="hint">
        💡 Выбор активной группы влияет на то, куда попадут новые объекты при рисовании.
      </p>
    </aside>

    <!-- Правая часть: тулбар + карта -->
    <main class="main">
      <div class="toolbar">
        <button @click="loadConfig('config1')">📍 Ярославль</button>
        <button @click="loadConfig('config2')">🌲 Лесная Поляна</button>
        <span class="sep"></span>
        <button @click="startDraw('LineString')">✏️ Линия</button>
        <button @click="startDraw('Polygon')">⬛ Полигон</button>
        <button @click="stopDraw">⛔ Стоп рисование</button>
        <span class="sep"></span>
        <button @click="clearFeatures">🧹 Очистить фигуры</button>
        <button @click="saveGeoJSON">💾 Экспорт GeoJSON</button>
        <label class="file">
          📥 Импорт <input type="file" @change="loadGeoJSON"/>
        </label>
      </div>
      <div ref="mapContainer" class="map"></div>
    </main>
  </div>
</template>

<script setup>
import {ref, onMounted} from "vue"
import "ol/ol.css"
import Map from "ol/Map"
import View from "ol/View"
import TileLayer from "ol/layer/Tile"
import OSM from "ol/source/OSM"
import {fromLonLat} from "ol/proj"

import VectorLayer from "ol/layer/Vector"
import VectorSource from "ol/source/Vector"
import Feature from "ol/Feature"
import Point from "ol/geom/Point"
import LineString from "ol/geom/LineString"
import Polygon from "ol/geom/Polygon"
import Overlay from "ol/Overlay"
import {Draw, defaults as defaultInteractions} from "ol/interaction"
import GeoJSON from "ol/format/GeoJSON"
import {Style, Fill, Stroke, Circle as CircleStyle} from "ol/style"
import {createEmpty, extend as extendExtent} from "ol/extent"

// ---------- реактивное состояние ----------
const mapContainer = ref(null)
let map, vectorSource, vectorLayer, popupOverlay, drawInteraction
const isDrawing = ref(false)

const activeGroup = ref(null) // текущая активная группа для новых объектов

// реестр групп: { [groupId]: { id, url } }
const groupRegistry = ref({})

// список групп для отрисовки (массив)
const groups = ref([])

// создание новой группы
const newGroupId = ref("")
const newGroupUrl = ref("")

// редактирование группы
const editingGroupId = ref(null)
const editGroupIdValue = ref("")
const editGroupUrlValue = ref("")

// ---------- стили ----------
const defaultStyle = new Style({
  fill: new Fill({color: "rgba(0, 150, 255, 0.2)"}),
  stroke: new Stroke({color: "#0077cc", width: 2}),
  image: new CircleStyle({
    radius: 6,
    fill: new Fill({color: "#ff0000"})
  })
})

const highlightStyle = new Style({
  fill: new Fill({color: "rgba(255, 200, 0, 0.4)"}),
  stroke: new Stroke({color: "#ff9900", width: 3}),
  image: new CircleStyle({
    radius: 7,
    fill: new Fill({color: "#ff9900"})
  })
})

// ---------- конфиги ----------
const configs = {
  config1: () => import("../assets/config1.json"),
  config2: () => import("../assets/config2.json")
}

// ---------- инициализация карты ----------
onMounted(async () => {
  vectorSource = new VectorSource()
  vectorLayer = new VectorLayer({source: vectorSource, style: defaultStyle})

  map = new Map({
    target: mapContainer.value,
    layers: [new TileLayer({source: new OSM()}), vectorLayer],
    view: new View({center: fromLonLat([39.8845, 57.6261]), zoom: 13}),
    // выключаем зум по двойному клику, чтобы dblclick открывал URL
    interactions: defaultInteractions({doubleClickZoom: false})
  })

  // popup (для своих popup на фичах)
  const popupElement = document.createElement("div")
  popupElement.className = "ol-popup"
  popupOverlay = new Overlay({
    element: popupElement,
    positioning: "bottom-center",
    stopEvent: false,
    offset: [0, -10]
  })
  map.addOverlay(popupOverlay)

  // клики по карте
  map.on("singleclick", (evt) => {
    const feature = map.forEachFeatureAtPixel(evt.pixel, (f) => f)
    if (feature) {
      const gid = feature.get("groupId")
      if (gid) {
        ensureGroupExists(gid, feature.get("url") || null)
        selectGroup(gid)
      }
      const popup = feature.get("popup")
      if (popup) {
        popupElement.innerHTML = `<div class="popup-content">${popup}</div>`
        popupOverlay.setPosition(evt.coordinate)
      }
    } else {
      popupOverlay.setPosition(undefined)
      resetStyles()
    }
  })

  map.on("dblclick", (evt) => {
    const feature = map.forEachFeatureAtPixel(evt.pixel, (f) => f)
    if (feature) {
      const gid = feature.get("groupId")
      const url = (gid && groupRegistry.value[gid]?.url) || feature.get("url")
      if (url) window.open(url, "_blank")
    }
  })

  await loadConfig("config1")
})

// ---------- группы: служебные функции ----------
function rebuildGroupsFromFeatures() {
  // пересобираем реестр на основе фичей
  const reg = {}
  vectorSource.getFeatures().forEach((f) => {
    const gid = f.get("groupId")
    if (!gid) return
    const url = f.get("url") || groupRegistry.value[gid]?.url || null
    if (!reg[gid]) reg[gid] = {id: gid, url}
  })
  groupRegistry.value = reg
  groups.value = Object.values(groupRegistry.value)
  // если активная группа исчезла — сбрасываем
  if (activeGroup.value && !groupRegistry.value[activeGroup.value]) {
    activeGroup.value = null
  }
}

function ensureGroupExists(id, url = null) {
  if (!id) return
  if (!groupRegistry.value[id]) {
    groupRegistry.value[id] = {id, url}
    groups.value = Object.values(groupRegistry.value)
  } else if (url && !groupRegistry.value[id].url) {
    groupRegistry.value[id].url = url
    groups.value = Object.values(groupRegistry.value)
  }
}

function selectGroup(groupId) {
  activeGroup.value = groupId
  // подсветка
  vectorSource.getFeatures().forEach((f) => {
    f.setStyle(f.get("groupId") === groupId ? highlightStyle : defaultStyle)
  })
  // fit по экстенту группы
  const feats = vectorSource.getFeatures().filter((f) => f.get("groupId") === groupId)
  if (feats.length) {
    let ext = createEmpty()
    feats.forEach((f) => extendExtent(ext, f.getGeometry().getExtent()))
    map.getView().fit(ext, {padding: [50, 50, 50, 50], duration: 500})
  }
}

function resetStyles() {
  vectorSource.getFeatures().forEach((f) => f.setStyle(defaultStyle))
  // не сбрасываем activeGroup, чтобы пользователь мог дальше рисовать в неё
}

// ---------- CRUD групп ----------
function createGroup() {
  const id = (newGroupId.value || "").trim()
  if (!id) return alert("Укажите id группы")
  if (groupRegistry.value[id]) return alert("Такая группа уже существует")
  groupRegistry.value[id] = {id, url: newGroupUrl.value.trim() || null}
  groups.value = Object.values(groupRegistry.value)
  activeGroup.value = id
  newGroupId.value = ""
  newGroupUrl.value = ""
}

function startEditGroup(g) {
  editingGroupId.value = g.id
  editGroupIdValue.value = g.id
  editGroupUrlValue.value = g.url || ""
}

function cancelEditGroup() {
  editingGroupId.value = null
  editGroupIdValue.value = ""
  editGroupUrlValue.value = ""
}

function applyEditGroup() {
  const oldId = editingGroupId.value
  const newId = (editGroupIdValue.value || "").trim()
  const newUrl = (editGroupUrlValue.value || "").trim() || null
  if (!oldId) return
  if (!newId) return alert("Новый id не может быть пустым")
  if (newId !== oldId && groupRegistry.value[newId]) {
    return alert("Группа с таким id уже есть")
  }

  // обновляем фичи
  vectorSource.getFeatures().forEach((f) => {
    if (f.get("groupId") === oldId) {
      f.set("groupId", newId)
      if (newUrl) f.set("url", newUrl)
    }
  })

  // обновляем реестр
  delete groupRegistry.value[oldId]
  groupRegistry.value[newId] = {id: newId, url: newUrl}
  groups.value = Object.values(groupRegistry.value)

  if (activeGroup.value === oldId) activeGroup.value = newId

  editingGroupId.value = null
  editGroupIdValue.value = ""
  editGroupUrlValue.value = ""
}

function deleteGroup(id) {
  if (!confirm(`Удалить группу "${id}"? (фигуры останутся без группы)`)) return
  // снимаем привязку у фичей
  vectorSource.getFeatures().forEach((f) => {
    if (f.get("groupId") === id) f.set("groupId", null)
  })
  // удаляем группу
  delete groupRegistry.value[id]
  groups.value = Object.values(groupRegistry.value)
  if (activeGroup.value === id) activeGroup.value = null
  // сбрасываем стили
  resetStyles()
}

// ---------- загрузка конфига ----------
async function loadConfig(key) {
  stopDraw()
  vectorSource.clear()
  groupRegistry.value = {}
  groups.value = []

  const cfg = (await configs[key]()).default
  map.getView().setCenter(fromLonLat(cfg.center))
  map.getView().setZoom(cfg.zoom)

  cfg.features.forEach((f) => {
    let geom
    if (f.type === "Point") {
      geom = new Point(fromLonLat(f.coordinates))
    } else if (f.type === "LineString") {
      geom = new LineString(f.coordinates.map((c) => fromLonLat(c)))
    } else if (f.type === "Polygon") {
      geom = new Polygon([f.coordinates[0].map((c) => fromLonLat(c))])
    }
    if (!geom) return
    const feature = new Feature({geometry: geom})
    if (f.popup) feature.set("popup", f.popup)
    if (f.groupId) feature.set("groupId", f.groupId)
    if (f.url) feature.set("url", f.url)
    vectorSource.addFeature(feature)
  })

  rebuildGroupsFromFeatures()
  resetStyles()
}

// ---------- рисование ----------
function startDraw(type) {
  stopDraw()
  drawInteraction = new Draw({source: vectorSource, type})
  map.addInteraction(drawInteraction)

  drawInteraction.on("drawstart", () => {
    isDrawing.value = true
  })

  drawInteraction.on("drawend", (evt) => {
    isDrawing.value = false
    // назначаем группу нарисованному объекту
    const gid = activeGroup.value || "user"
    ensureGroupExists(gid)
    evt.feature.set("groupId", gid)
    // если у группы есть URL — подставим его фиче
    const gUrl = groupRegistry.value[gid]?.url || null
    if (gUrl) evt.feature.set("url", gUrl)
    rebuildGroupsFromFeatures()
  })
}

function stopDraw() {
  if (drawInteraction) {
    // фикс: если пользователь в процессе рисования — завершаем фигуру, чтобы не пропала
    try {
      if (isDrawing.value && typeof drawInteraction.finishDrawing === "function") {
        drawInteraction.finishDrawing()
      }
    } catch (e) {
      // если finishDrawing недоступен в вашей версии OL — просто игнорируем
    }
    map.removeInteraction(drawInteraction)
    drawInteraction = null
    isDrawing.value = false
  }
}

function clearFeatures() {
  vectorSource.clear()
  // группы оставляем (пустые), чтобы пользователь мог рисовать в них дальше
  resetStyles()
}

// ---------- экспорт / импорт GeoJSON ----------
function saveGeoJSON() {
  const format = new GeoJSON()
  const data = format.writeFeatures(vectorSource.getFeatures(), {
    featureProjection: "EPSG:3857",
    dataProjection: "EPSG:4326" // пишем в стандартные долгота/широта
  })
  const blob = new Blob([data], {type: "application/json"})
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = "map-data.geojson"
  a.click()
  URL.revokeObjectURL(url)
}

function loadGeoJSON(event) {
  const file = event.target.files[0]
  if (!file) return
  const reader = new FileReader()
  reader.onload = () => {
    const format = new GeoJSON()
    const features = format.readFeatures(reader.result, {
      featureProjection: "EPSG:3857",
      dataProjection: "EPSG:4326"
    })
    vectorSource.addFeatures(features)
    rebuildGroupsFromFeatures()
  }
  reader.readAsText(file)
}

// ---------- открытие URL группы ----------
function openGroupUrl(group) {
  if (group?.url) window.open(group.url, "_blank")
}
</script>

<style>
/* layout */
.container {
  display: flex;
  height: 100vh;
  font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif;
}

.sidebar {
  width: 260px;
  background: #f6f7f9;
  border-right: 1px solid #dcdfe6;
  padding: 12px;
  overflow-y: auto;
}

.main {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
  background: #fff;
  border-bottom: 1px solid #dcdfe6;
  padding: 8px;
}

.toolbar .sep {
  width: 1px;
  height: 24px;
  background: #e3e6eb;
  margin: 0 4px;
}

.file input[type="file"] {
  display: inline-block;
}

.map {
  flex: 1;
}

/* sidebar */
.group-create {
  display: grid;
  gap: 6px;
  margin-bottom: 12px;
}

.group-create input {
  padding: 6px 8px;
  border: 1px solid #cfd6e4;
  border-radius: 6px;
  font-size: 14px;
}

.group-create button {
  padding: 6px 8px;
  border: 1px solid #1e80ff;
  background: #1e80ff;
  color: white;
  border-radius: 6px;
  cursor: pointer;
}

.group-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: grid;
  gap: 8px;
}

.group-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.group-title {
  cursor: pointer;
}

.group-actions button {
  margin-left: 6px;
  border: 1px solid #cfd6e4;
  background: #fff;
  border-radius: 6px;
  padding: 2px 6px;
  cursor: pointer;
}

.group-edit {
  display: grid;
  gap: 6px;
  margin-top: 6px;
}

.group-edit input {
  padding: 6px 8px;
  border: 1px solid #cfd6e4;
  border-radius: 6px;
}

.edit-actions {
  display: flex;
  gap: 6px;
}

.sidebar li {
  padding: 8px;
  border: 1px solid #e5e8ef;
  border-radius: 8px;
  background: #fff;
}

.sidebar li.active {
  outline: 2px solid #1e80ff;
}

.hint {
  margin-top: 10px;
  font-size: 12px;
  color: #666;
}

/* popup */
.ol-popup {
  background: white;
  padding: 6px 10px;
  border-radius: 6px;
  border: 1px solid #cfd6e4;
  font-size: 13px;
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.1);
}
</style>
