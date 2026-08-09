<script setup>
import Icon from './Icon.vue';

defineProps({
    src: { type: String, default: null },
    alt: { type: String, default: '' },
    size: { type: String, default: 'h-10 w-10' },
});
</script>

<template>
    <img
        v-if="src"
        :src="src"
        :alt="alt"
        :class="size"
        class="rounded-md object-cover border border-slate-200 shrink-0"
    />
    <div
        v-else
        :class="size"
        class="rounded-md border border-slate-200 bg-slate-100 text-slate-300 flex items-center justify-center shrink-0"
    >
        <Icon name="photo" class="h-1/2 w-1/2" />
    </div>
</template>
