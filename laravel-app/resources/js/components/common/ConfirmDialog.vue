<script setup>
import { useConfirm } from '@/composables/useConfirm';

const { state, respond } = useConfirm();
</script>

<template>
    <Teleport to="body">
        <div v-if="state.visible" class="fixed inset-0 z-[110] flex items-center justify-center bg-overlay-solid/50 px-4">
            <div role="alertdialog" aria-modal="true" class="bg-white rounded-lg shadow-xl w-full max-w-sm p-6">
                <h3 class="text-base font-semibold text-slate-900">{{ state.title }}</h3>
                <p class="mt-2 text-sm text-slate-600">{{ state.message }}</p>
                <div class="mt-6 flex justify-end gap-3">
                    <button
                        type="button"
                        class="px-4 py-2 text-sm font-medium rounded-md bg-[#f24c17] text-onbrand hover:bg-[#d8430f]"
                        @click="respond(false)"
                    >
                        {{ state.cancelText }}
                    </button>
                    <button
                        type="button"
                        :class="[
                            'px-4 py-2 text-sm font-medium rounded-md',
                            state.danger
                                ? 'text-onbrand bg-danger-solid hover:bg-danger-solid-hover'
                                : 'text-on-accent-solid bg-accent-solid hover:bg-accent-solid-hover',
                        ]"
                        @click="respond(true)"
                    >
                        {{ state.confirmText }}
                    </button>
                </div>
            </div>
        </div>
    </Teleport>
</template>
