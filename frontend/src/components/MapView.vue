<template>
  <div ref="mapRoot" class="map-root"></div>
  <PopupOverlay ref="popupComp" :html="popupHtml" :visible="popupVisible"/>
</template>

<script setup>
import {ref, watch, onMounted, nextTick, defineProps, defineEmits, defineExpose} from "vue"
import Map from "ol/Map"
import View from "ol/View"
import TileLayer from "ol/layer/Tile"
import OSM from "ol/source/OSM"
import {fromLonLat, toLonLat} from "ol/proj"
import VectorSource from "ol/source/Vector"
import VectorLayer from "ol/layer/Vector"
import Feature from "ol/Feature"
import Point from "ol/geom/Point"
import LineString from "ol/geom/LineString"
import Polygon from "ol/geom/Polygon"
import {Draw, Modify, Select, defaults as defaultInteractions} from "ol/interaction"
import Overlay from "ol/Overlay"
import {Style, Fill, Stroke, Circle as CircleStyle} from "ol/style"
import {createEmpty, extend as extendExtent} from "ol/extent"
import PopupOverlay from "./PopupOverlay.vue"

const props = defineProps({
  geoConfig: {type: Object, required: true},
  activeGroup: {type: String, default: null}
})
const emit = defineEmits(["updateConfig"])

const mapRoot = ref(null)
const popupComp = ref(null)

let map = null
let vectorSource = null
let vectorLayer = null
let drawInteraction = null
let modifyInteraction = null
let selectInteraction = null
let overlay = null

const popupHtml = ref("")
const popupVisible = ref(false)

let idCounter = 1

// стили
const defaultStyle = new Style({
  fill: new Fill({color: "rgba(0,150,255,0.14)"}),
  stroke: new Stroke({color: "#0077cc", width: 2}),
  image: new CircleStyle({radius: 6, fill: new Fill({color: "#ff0000"})})
})
const highlightStyle = new Style({
  fill: new Fill({color: "rgba(255,200,0,0.4)"}),
  stroke: new Stroke({color: "#ff9900", width: 3}),
  image: new CircleStyle({radius: 7, fill: new Fill({color: "#ff9900"})})
})

function genFeatureId() {
  return `feat_${Date.now()}_${idCounter++}`
}

function featureToGeo(f) {
  // convert OL feature to geoConfig feature object with lon/lat coords
  const geom = f.getGeometry()
  const type = geom.getType()
  let coords
  if (type === "Point") {
    coords = toLonLat(geom.getCoordinates())
  } else if (type === "LineString") {
    coords = geom.getCoordinates().map(c => toLonLat(c))
  } else if (type === "Polygon") {
    // array of rings
    coords = geom.getCoordinates().map(ring => ring.map(c => toLonLat(c)))
  } else {
    coords = null
  }
  return {
    id: f.getId(),
    type,
    coordinates: coords,
    groupId: f.get("groupId") || null,
    popup: f.get("popup") || null,
    url: f.get("url") || null
  }
}

function createFeatureFromGeo(gf) {
  let geom = null
  if (gf.type === "Point") {
    geom = new Point(fromLonLat(gf.coordinates))
  } else if (gf.type === "LineString") {
    geom = new LineString(gf.coordinates.map(c => fromLonLat(c)))
  } else if (gf.type === "Polygon") {
    geom = new Polygon(gf.coordinates.map(ring => ring.map(c => fromLonLat(c))))
  }
  if (!geom) return null
  const f = new Feature({geometry: geom})
  f.setId(gf.id || genFeatureId())
  if (gf.groupId) f.set("groupId", gf.groupId)
  if (gf.popup) f.set("popup", gf.popup)
  if (gf.url) f.set("url", gf.url)
  f.setStyle(defaultStyle)
  return f
}

// инициализация карты
onMounted(async () => {
  vectorSource = new VectorSource()
  vectorLayer = new VectorLayer({source: vectorSource, style: defaultStyle})

  map = new Map({
    target: mapRoot.value,
    layers: [new TileLayer({source: new OSM()}), vectorLayer],
    view: new View({
      center: fromLonLat(props.geoConfig.center || [39.8845, 57.6261]),
      zoom: props.geoConfig.zoom || 12
    }),
    interactions: defaultInteractions({doubleClickZoom: false})
  })

  await nextTick()
  const el = popupComp.value?.$el
  overlay = new Overlay({element: el, positioning: "bottom-center", offset: [0, -12], stopEvent: false})
  map.addOverlay(overlay)

  // Select + Modify
  selectInteraction = new Select()
  modifyInteraction = new Modify({source: vectorSource})
  map.addInteraction(selectInteraction)
  map.addInteraction(modifyInteraction)

  // events
  map.on("singleclick", (evt) => {
    const f = map.forEachFeatureAtPixel(evt.pixel, ft => ft)
    if (f) {
      const gid = f.get("groupId")
      if (gid) highlightGroup(gid)
      const popupText = f.get("popup")
      if (popupText) {
        popupHtml.value = popupText
        overlay.setPosition(evt.coordinate)
        popupVisible.value = true
      } else {
        popupVisible.value = false
      }
    } else {
      popupVisible.value = false
      resetStyles()
      selectInteraction.getFeatures().clear()
      // nothing selected -> emit update maybe
    }
  })

  map.on("dblclick", (evt) => {
    const f = map.forEachFeatureAtPixel(evt.pixel, ft => ft)
    if (f) {
      const gid = f.get("groupId")
      const url = (gid && (props.geoConfig.groups.find(g => g.id === gid) || {}).url) || f.get("url")
      if (url) window.open(url, "_blank")
    }
  })

  // react to modify end -> sync geoConfig
  modifyInteraction.on("modifyend", () => {
    syncFeaturesToGeoConfig()
  })

  // load initial config
  loadGeoConfigToMap(props.geoConfig)
})

// helper: reset styles
function resetStyles() {
  vectorSource.getFeatures().forEach(ft => ft.setStyle(defaultStyle))
}

// highlight group
function highlightGroup(groupId) {
  vectorSource.getFeatures().forEach(ft => {
    ft.setStyle(ft.get("groupId") === groupId ? highlightStyle : defaultStyle)
  })
}

// load geoConfig into map
function loadGeoConfigToMap(cfg) {
  stopDraw()
  vectorSource.clear()
  if (cfg.center) map.getView().setCenter(fromLonLat(cfg.center))
  if (cfg.zoom !== undefined) map.getView().setZoom(cfg.zoom)
  if (Array.isArray(cfg.features)) {
    cfg.features.forEach(gf => {
      const f = createFeatureFromGeo(gf)
      if (f) vectorSource.addFeature(f)
    })
  }
  // sync IDs and groups: ensure groups exist as provided by cfg
  // no extra work needed here; features already have groupId
  // emit initial update (to ensure any normalization)
  emit("updateConfig", {groups: cfg.groups || [], features: cfg.features || [], center: cfg.center, zoom: cfg.zoom})
}

// start drawing

function startDraw(type) {
  stopDraw()
  drawInteraction = new Draw({source: vectorSource, type})
  map.addInteraction(drawInteraction)
  drawInteraction.on("drawend", (evt) => {
    const f = evt.feature
    if (!f.getId()) f.setId(genFeatureId())
    if (props.activeGroup) f.set("groupId", props.activeGroup)
    else f.set("groupId", null)
    f.set("popup", f.get("popup") || null)
    f.setStyle(defaultStyle)
    syncFeaturesToGeoConfig()
  })
}

function deleteGroupFromMap(groupId) {
  vectorSource.getFeatures().forEach(f => {
    if (f.get("groupId") === groupId) {
      vectorSource.removeFeature(f)
    }
  })
  syncFeaturesToGeoConfig()
}

// stop draw (finish current if drawing)
function stopDraw() {
  if (drawInteraction) {
    try {
      if (typeof drawInteraction.finishDrawing === "function") drawInteraction.finishDrawing()
    } catch (e) {
      console.error(e)
    }
    map.removeInteraction(drawInteraction)
    drawInteraction = null
    // ensure config up to date
    syncFeaturesToGeoConfig()
  }
}

// delete selected features
function deleteSelected() {
  const sels = selectInteraction.getFeatures().getArray().slice()
  if (!sels.length) return
  if (!confirm(`Удалить ${sels.length} выбранных объектов?`)) return
  sels.forEach(f => {
    vectorSource.removeFeature(f)
  })
  selectInteraction.getFeatures().clear()
  syncFeaturesToGeoConfig()
}

// sync all OL features to props.geoConfig.features and emit update
function syncFeaturesToGeoConfig() {
  const feats = vectorSource.getFeatures()
  const geoFeatures = feats.map(f => featureToGeo(f))
  // emit full new config object (App will replace reactive arrays)
  const out = {
    center: toLonLat(map.getView().getCenter()),
    zoom: map.getView().getZoom(),
    groups: props.geoConfig.groups || [],
    features: geoFeatures
  }
  emit("updateConfig", out)
}

// export geoConfig as string (with lon/lat coords)
function exportGeoConfig() {
  // ensure up-to-date
  syncFeaturesToGeoConfig()
  const cfg = {
    center: toLonLat(map.getView().getCenter()),
    zoom: map.getView().getZoom(),
    groups: props.geoConfig.groups || [],
    features: (vectorSource.getFeatures() || []).map(f => featureToGeo(f))
  }
  return JSON.stringify(cfg, null, 2)
}

// import geoConfig object (from App)
function importGeoConfig(obj) {
  if (!obj) return
  // normalize groups and features
  const cfg = {
    center: obj.center || props.geoConfig.center,
    zoom: obj.zoom || props.geoConfig.zoom,
    groups: Array.isArray(obj.groups) ? obj.groups : [],
    features: Array.isArray(obj.features) ? obj.features : []
  }
  loadGeoConfigToMap(cfg)
}

// rename group: change feature.groupId
function renameGroupOnMap(oldId, newId, newName, newUrl) {
  vectorSource.getFeatures().forEach(f => {
    if (f.get("groupId") === oldId) {
      f.set("groupId", newId)
      if (newUrl) f.set("url", newUrl)
    }
  })
  // also update geoConfig groups are managed by App (it will pass new geoConfig)
  syncFeaturesToGeoConfig()
}

// assign selected features to group
function assignSelectedToGroup(groupId) {
  const sel = selectInteraction.getFeatures().getArray()
  sel.forEach(f => f.set("groupId", groupId))
  syncFeaturesToGeoConfig()
}

// center on group
function centerOnGroup(groupId) {
  const feats = vectorSource.getFeatures().filter(f => f.get("groupId") === groupId)
  if (!feats.length) return
  let ext = createEmpty()
  feats.forEach(f => extendExtent(ext, f.getGeometry().getExtent()))
  map.getView().fit(ext, {padding: [40, 40, 40, 40], duration: 400})
  highlightGroup(groupId)
}

// expose methods to parent via ref
defineExpose({
  startDraw,
  stopDraw,
  deleteSelected,
  exportGeoConfig,
  importGeoConfig,
  renameGroupOnMap,
  assignSelectedToGroup,
  deleteGroupFromMap,
  centerOnGroup,
  getAllGeoFeatures: () => (vectorSource.getFeatures() || []).map(f => featureToGeo(f))
})

// watch for incoming geoConfig changes from parent
watch(() => props.geoConfig, (nv) => {
  if (!nv) return
  // naive reload: if groups or features changed externally — reload map
  loadGeoConfigToMap(nv)
}, {deep: true})

</script>

<style scoped>
.map-root {
  width: 100%;
  height: calc(100vh - 0px);
}
</style>
