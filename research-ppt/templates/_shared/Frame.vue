<script setup lang="ts">
import { computed, unref } from 'vue'
import { useSlideContext } from '@slidev/client'

const props = withDefaults(defineProps<{
  variant: 'mc' | 'nku'
  mode?: 'default' | 'cover' | 'agenda' | 'center' | 'end'
  logo?: string
  leftArt?: string
  rightArt?: string
}>(), { mode: 'default' })
const { $frontmatter, $page, $slidev } = useSlideContext()
const settings = computed(() => ({ ...$slidev.configs, ...unref($frontmatter) }) as Record<string, any>)
const isNkuAgenda = computed(() => props.variant === 'nku' && props.mode === 'agenda')
const hasHeader = computed(() => ['default', 'center'].includes(props.mode) || (props.mode === 'agenda' && !isNkuAgenda.value))
const hasFooter = computed(() => props.mode !== 'end' && !(props.variant === 'nku' && ['cover', 'agenda'].includes(props.mode)))
const items = computed(() => Array.isArray(settings.value.agenda) ? settings.value.agenda : [])
</script>

<template>
  <div class="slidev-layout ppt-theme" :data-variant="variant" :data-mode="mode" :data-agenda-style="settings.agendaStyle || 'tiles'">
    <template v-if="mode === 'cover'">
      <div class="cover-brand">
        <img v-if="settings.logo || logo" :src="settings.logo || logo" alt="南开大学标识" />
        <span v-else>{{ settings.organization || '示例单位' }}</span>
      </div>
      <div class="cover-band">
        <template v-if="variant === 'nku'"><span class="cover-rule top"></span><span class="cover-rule bottom"></span></template>
        <slot />
      </div>
      <img v-if="settings.leftArt || leftArt" class="cover-art left" :src="settings.leftArt || leftArt" alt="左侧校园建筑装饰" />
      <img v-if="settings.rightArt || rightArt" class="cover-art right" :src="settings.rightArt || rightArt" alt="右侧校园建筑装饰" />
      <div class="cover-author">
        <div class="author-name">{{ settings.author || 'Your Name' }}</div>
        <div class="cover-affiliation">{{ settings.organization || '示例单位' }}</div>
        <div v-if="settings.date" class="cover-date">{{ settings.date }}</div>
      </div>
    </template>
    <template v-else-if="mode === 'end'">
      <main class="end-content"><slot /></main>
    </template>
    <template v-else>
      <header v-if="hasHeader" class="paper-title"><h1>{{ settings.heading || (mode === 'agenda' ? 'Contents' : '') }}</h1></header>
      <div v-if="isNkuAgenda" class="agenda-rail"></div>
      <aside v-if="isNkuAgenda" class="agenda-label">
        <div>{{ settings.agendaLabel || '汇报\n提纲' }}</div><span class="agenda-divider"></span><small>CONTENTS</small>
      </aside>
      <main class="theme-body" :class="{ 'theme-centered': mode === 'center' }" data-qa-content>
        <ol v-if="mode === 'agenda' && items.length" class="agenda-items">
          <li v-for="(item, i) in items" :key="i" :class="{ active: i + 1 === Number(settings.active || 1) }">
            <span class="agenda-index">{{ variant === 'mc' ? (i + 1) + '.' : String(i + 1).padStart(2, '0') }}</span><span class="agenda-text">{{ item }}</span>
          </li>
        </ol>
        <slot v-else />
      </main>
    </template>
    <footer v-if="hasFooter" class="paper-footer">
      <span>{{ settings.footerLeft || settings.author || '示例作者' }}</span>
      <span>{{ settings.footerTitle || settings.title || '演示标题' }}</span>
      <span>{{ $page }}<template v-if="settings.showTotal"> / {{ $slidev.slides.length }}</template></span>
    </footer>
  </div>
</template>
