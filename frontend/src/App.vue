<template>
  <div class="app-root">
    <GroupPanel
      :groups="geoConfig.groups"
      :activeGroup="activeGroup"
      @create="onCreateGroup"
      @select="onSelectGroup"
      @delete="onDeleteGroup"
      @rename="onRenameGroup"
      @open="onOpenGroup"
      @assign="onAssignToGroup"
    />

    <div class="right">
      <ToolbarDraw
        :activeGroup="activeGroup"
        @load-config="onLoadConfig"
        @draw-point="onDrawPoint"
        @draw-line="onDrawLine"
        @draw-polygon="onDrawPolygon"
        @stop-draw="onStopDraw"
        @delete-selected="onDeleteSelected"
        @save-config="onSaveConfig"
        @import-config="onImportConfig"
      />

      <MapView
        ref="mapRef"
        :geoConfig="geoConfig"
        :activeGroup="activeGroup"
        @updateConfig="onUpdateConfig"
      />
    </div>
  </div>
</template>

<script setup>
import { reactive, ref} from "vue"
import MapView from "./components/MapView.vue"
import ToolbarDraw from "./components/ToolbarDraw.vue"
import GroupPanel from "./components/GroupPanel.vue"
import config from "./assets/geoConfig.json"

const mapRef = ref(null)

// reactive geoConfig state
const geoConfig = reactive({
  center: config.center,
  zoom: config.zoom,
  groups: JSON.parse(JSON.stringify(config.groups)),
  features: JSON.parse(JSON.stringify(config.features))
})

const activeGroup = ref(null)

// respond to MapView update
function onUpdateConfig(newCfg) {
  // replace arrays to keep reactivity
  geoConfig.center = newCfg.center || geoConfig.center
  geoConfig.zoom = newCfg.zoom || geoConfig.zoom
  geoConfig.groups = Array.isArray(newCfg.groups) ? newCfg.groups : geoConfig.groups
  geoConfig.features = Array.isArray(newCfg.features) ? newCfg.features : geoConfig.features
}

// Groups
function onCreateGroup({ id, name, url }) {
  geoConfig.groups.push({ id, name, url })
  activeGroup.value = id
}
function onSelectGroup(id) {
  activeGroup.value = id
  if (id && mapRef.value) mapRef.value.centerOnGroup(id)
}
function onDeleteGroup(id) {
  geoConfig.groups = geoConfig.groups.filter(g => g.id !== id)
  geoConfig.features = geoConfig.features.filter(f => f.groupId !== id)
  if (mapRef.value) mapRef.value.deleteGroupFromMap(id)
  if (activeGroup.value === id) activeGroup.value = null
}
function onRenameGroup({ id, name, url }) {
  const g = geoConfig.groups.find(gr => gr.id === id)
  if (g) { g.name = name; g.url = url }
}
function onOpenGroup(g) {
  if (g && g.url) window.open(g.url, "_blank")
}
function onAssignToGroup(id) {
  if (mapRef.value) mapRef.value.assignSelectedToGroup(id)
}

// Toolbar
function applyConfig(cfg) {
  geoConfig.center = cfg.center
  geoConfig.zoom = cfg.zoom
  geoConfig.groups = JSON.parse(JSON.stringify(cfg.groups))
  geoConfig.features = JSON.parse(JSON.stringify(cfg.features))
  activeGroup.value = null
}
function onDrawPoint() { mapRef.value && mapRef.value.startDraw("Point") }
function onDrawLine() { mapRef.value && mapRef.value.startDraw("LineString") }
function onDrawPolygon() { mapRef.value && mapRef.value.startDraw("Polygon") }
function onStopDraw() { mapRef.value && mapRef.value.stopDraw() }
function onDeleteSelected() { mapRef.value && mapRef.value.deleteSelected() }
function onSaveConfig() {
  const data = mapRef.value && mapRef.value.exportGeoConfig()
  if (!data) return
  const blob = new Blob([data], { type: "application/json" })
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = "geoConfig.json"
  a.click()
  URL.revokeObjectURL(url)
}
function onImportConfig(cfg) {
  applyConfig(cfg)
  if (mapRef.value) mapRef.value.importGeoConfig(cfg)
}
</script>

<style>
.app-root { display:flex; height:100vh; }
.right { flex:1; display:flex; flex-direction:column; }
</style>
