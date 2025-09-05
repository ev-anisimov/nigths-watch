<!-- src/views/MapPage.vue -->
<template>
  <div class="container-fluid">
    <div class="row">
      <div class="col-md-3">
        <GroupPanel />
      </div>
      <div class="col-md-9">
        <div class="map-container">
          <MapView />
        </div>
        <ToolbarDraw />
      </div>
    </div>
  </div>
</template>

<script setup>
import MapView from '@/components/MapView.vue';
import ToolbarDraw from '@/components/ToolbarDraw.vue';
import GroupPanel from '@/components/GroupPanel.vue';
</script>

<style>
.map-container {
  height: 600px;
  width: 100%;
}
</style>