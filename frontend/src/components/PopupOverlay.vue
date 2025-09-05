<template>
  <div ref="container" class="ol-popup" v-show="visible" v-html="html"></div>
</template>

<script setup>
import { ref, defineProps } from "vue"

defineProps({
  html: { type: String, default: "" },
  visible: { type: Boolean, default: false }
})

const container = ref(null)
</script>

<style scoped>
.ol-popup {
  background: white;
  padding: 6px 10px;
  border-radius: 6px;
  border: 1px solid #cfd6e4;
  font-size: 13px;
  box-shadow: 0 6px 18px rgba(0,0,0,0.12);
  white-space: nowrap;
}
</style>
