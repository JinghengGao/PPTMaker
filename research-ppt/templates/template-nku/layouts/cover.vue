<script setup lang="ts">
import Frame from '../../_shared/Frame.vue'
import logo from '../assets/logo.png'
import leftArt from '../assets/building-left.png'
import rightArt from '../assets/building-right.png'
</script>

<template>
  <Frame variant="nku" mode="cover" :logo="logo" :left-art="leftArt" :right-art="rightArt"><slot /></Frame>
</template>
