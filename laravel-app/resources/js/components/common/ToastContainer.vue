<script setup>
import { useToast } from '@/composables/useToast';

const { toasts, remove } = useToast();

const styles = {
    success: 'bg-success-solid',
    error: 'bg-danger-solid',
    info: 'bg-ink-solid',
};
</script>

<template>
    <div class="fixed top-4 right-4 z-[100] flex flex-col gap-2 w-[calc(100%-2rem)] max-w-sm">
        <TransitionGroup name="toast">
            <div
                v-for="toast in toasts"
                :key="toast.id"
                :class="[styles[toast.type] || styles.info, 'text-onbrand rounded-lg shadow-lg px-4 py-3 flex items-start gap-3']"
            >
                <span class="flex-1 text-sm">{{ toast.message }}</span>
                <button
                    type="button"
                    class="text-onbrand/80 hover:text-onbrand leading-none"
                    @click="remove(toast.id)"
                >
                    &times;
                </button>
            </div>
        </TransitionGroup>
    </div>
</template>

<style scoped>
.toast-enter-active,
.toast-leave-active {
    transition: all 0.2s ease;
}
.toast-enter-from,
.toast-leave-to {
    opacity: 0;
    transform: translateX(1rem);
}
</style>
