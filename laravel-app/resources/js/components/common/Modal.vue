<script setup>
import { onMounted, onUnmounted } from 'vue';

const props = defineProps({
    modelValue: { type: Boolean, default: false },
    title: { type: String, default: '' },
    size: { type: String, default: 'md' }, // sm | md | lg | xl
});

const emit = defineEmits(['update:modelValue']);

const sizes = {
    sm: 'max-w-md',
    md: 'max-w-xl',
    lg: 'max-w-3xl',
    xl: 'max-w-5xl',
};

function close() {
    emit('update:modelValue', false);
}

function onKeydown(event) {
    if (event.key === 'Escape' && props.modelValue) close();
}

onMounted(() => document.addEventListener('keydown', onKeydown));
onUnmounted(() => document.removeEventListener('keydown', onKeydown));
</script>

<template>
    <Teleport to="body">
        <div v-if="modelValue" class="fixed inset-0 z-[90] flex items-start sm:items-center justify-center bg-overlay-solid/50 p-4 overflow-y-auto">
            <div class="absolute inset-0" @click="close" />
            <div role="dialog" aria-modal="true" :class="['relative bg-white rounded-lg shadow-xl w-full my-8 sm:my-0', sizes[size]]">
                <div class="flex items-center justify-between px-5 py-4 border-b border-slate-200">
                    <h3 class="text-base font-semibold text-slate-900">{{ title }}</h3>
                    <button type="button" class="flex items-center justify-center h-7 w-7 rounded-md bg-[#f24c17] text-onbrand hover:bg-[#d8430f] text-lg leading-none" @click="close">&times;</button>
                </div>
                <div class="px-5 py-4 max-h-[75vh] overflow-y-auto">
                    <slot />
                </div>
                <div v-if="$slots.footer" class="px-5 py-4 border-t border-slate-200 flex justify-end gap-3">
                    <slot name="footer" />
                </div>
            </div>
        </div>
    </Teleport>
</template>
