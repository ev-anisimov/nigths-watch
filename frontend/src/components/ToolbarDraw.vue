<template>
  <div class="toolbar">
    <button @click="$emit('load-config','config1')">📍 Ярославль</button>
    <button @click="$emit('load-config','config2')">🌲 Лесная Поляна</button>

    <span class="sep"></span>

    <button @click="$emit('draw-point')">📌 Точка</button>
    <button @click="$emit('draw-line')">✏️ Линия</button>
    <button @click="$emit('draw-polygon')">⬛ Полигон</button>
    <button @click="$emit('stop-draw')">⛔ Стоп</button>

    <span class="sep"></span>

    <button @click="$emit('delete-selected')">✖ Удалить выбранные</button>
    <button @click="$emit('save-config')">💾 Экспорт</button>

    <label class="file">
      📥 Импорт
      <input type="file" @change="onFile" />
    </label>

    <span class="sep"></span>
    <span v-if="activeGroup">🎯 Активная группа: <b>{{ activeGroup }}</b></span>
    <span v-else>— группа не выбрана</span>
  </div>
</template>

<script setup>
import { defineProps, defineEmits } from "vue"
defineProps({
  activeGroup: { type: String, default: null }
})
const emit = defineEmits([
  "load-config","draw-point","draw-line","draw-polygon","stop-draw",
  "delete-selected","save-config","import-config"
])

function onFile(e) {
  const f = e.target.files && e.target.files[0]
  if (!f) return
  const reader = new FileReader()
  reader.onload = () => {
    try {
      const data = JSON.parse(reader.result)
      emit("import-config", data)
    } catch {
      alert("Ошибка при чтении файла")
    }
  }
  reader.readAsText(f)
}
</script>

<style scoped>
.toolbar {
  display:flex;
  gap:8px;
  padding:8px;
  background:#fff;
  border-bottom:1px solid #e6eaef;
  align-items:center;
  flex-wrap:wrap;
}
.sep { width:1px;height:28px;background:#e6eaef;margin:0 6px; }
.file input { display:none; }
</style>
