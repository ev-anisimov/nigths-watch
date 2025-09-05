<template>
  <aside class="sidebar">
    <h3>Группы</h3>

    <div class="create">
      <input v-model="newName" placeholder="имя группы (обязательно)" />
      <input v-model="newUrl" placeholder="URL (опционально)" />
      <button @click="create">＋ Создать</button>
    </div>

    <ul class="list">
      <li v-for="g in groups" :key="g.id" :class="{ active: activeGroup === g.id }">
        <div class="row">
          <div class="title" @click="$emit('select', g.id)" @dblclick="$emit('open', g)">
            {{ g.id }} — {{ g.name }}
          </div>
          <div class="actions">
            <button @click="assign(g.id)">📌 Назначить выбранные</button>
            <button @click="edit(g)">✏️</button>
            <button @click="remove(g.id)">🗑</button>
          </div>
        </div>

        <div v-if="editingId === g.id" class="edit">
          <input v-model="editName" />
          <input v-model="editUrl" />
          <div class="edit-actions">
            <button @click="applyEdit">✔️</button>
            <button @click="cancelEdit">✖</button>
          </div>
        </div>
      </li>
    </ul>

    <p class="hint">Сначала создайте группу и выделите её. Новые объекты будут автоматически попадать в активную группу.</p>
  </aside>
</template>

<script setup>
import { ref, defineEmits, defineProps } from "vue"
defineProps({
  groups: { type: Array, default: () => [] },
  activeGroup: { type: String, default: null }
})
const emit = defineEmits(["create","select","delete","rename","open","assign"])

const newName = ref("")
const newUrl = ref("")
const editingId = ref(null)
const editName = ref("")
const editUrl = ref("")

function create() {
  const name = (newName.value || "").trim()
  if (!name) return alert("Введите имя группы")
  const id = generateId(name)
  emit("create", { id, name, url: newUrl.value || null })
  newName.value = ""
  newUrl.value = ""
}

function generateId(name) {
  return name.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-_]/g, "") + "-" + Date.now().toString().slice(-4)
}
function edit(g) {
  editingId.value = g.id
  editName.value = g.name
  editUrl.value = g.url || ""
}

function cancelEdit() {
  editingId.value = null
  editName.value = ""
  editUrl.value = ""
}

function applyEdit() {
  if (!editingId.value) return
  const name = (editName.value || "").trim()
  if (!name) return alert("Имя не может быть пустым")
  emit("rename", { id: editingId.value, name, url: editUrl.value || null })
  cancelEdit()
}

function remove(id) {
  if (!confirm(`Удалить группу "${id}" и все её объекты?`)) return
  emit("delete", id)
}
function assign(id) {
  emit("assign", id)
}
</script>

<style scoped>
.sidebar { width:280px;padding:12px;background:#f7f8fa;border-right:1px solid #e6eaef; overflow:auto }
.create { display:grid; gap:6px;margin-bottom:12px }
.create input { padding:6px;border-radius:6px;border:1px solid #dfe6ef }
.create button { padding:6px;border-radius:6px;background:#1e80ff;color:#fff;border:none;cursor:pointer }
.list { list-style:none;padding:0;margin:0;display:grid;gap:8px }
.row { display:flex;justify-content:space-between;align-items:center;gap:6px }
.title { cursor:pointer }
.actions button { margin-left:4px }
.edit { margin-top:6px; display:grid; gap:6px }
.edit-actions { display:flex; gap:6px }
.hint { margin-top:10px;font-size:12px;color:#666 }
li.active { outline:2px solid #1e80ff;background:#fff;padding:6px;border-radius:6px }
li { background:#fff;padding:6px;border-radius:6px;border:1px solid #ecf0f6 }
</style>
