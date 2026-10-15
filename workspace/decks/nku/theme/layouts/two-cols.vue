<script setup lang="ts">
import Frame from '../../../../shared/Frame.vue'
</script>

<template>
  <Frame variant="nku" mode="default"><div class="two-cols"><div><slot /></div><div><slot name="right" /></div></div></Frame>
</template>
