<script setup>
import { nextTick, ref, watch } from 'vue';
import Cropper from 'cropperjs';
import 'cropperjs/dist/cropper.css';
import Modal from './Modal.vue';

const props = defineProps({
    modelValue: { type: Boolean, default: false },
    file: { type: [File, Object], default: null },
    outputSize: { type: Number, default: 600 },
});

const emit = defineEmits(['update:modelValue', 'cropped']);

const imageEl = ref(null);
const objectUrl = ref(null);
let cropper = null;

function destroyCropper() {
    cropper?.destroy();
    cropper = null;
    if (objectUrl.value) {
        URL.revokeObjectURL(objectUrl.value);
        objectUrl.value = null;
    }
}

watch(
    () => props.modelValue,
    async (open) => {
        if (!open) {
            destroyCropper();
            return;
        }
        if (!props.file) return;

        objectUrl.value = URL.createObjectURL(props.file);
        await nextTick();
        cropper = new Cropper(imageEl.value, {
            aspectRatio: 1,
            viewMode: 1,
            autoCropArea: 1,
            background: false,
        });
    }
);

function close() {
    emit('update:modelValue', false);
}

function confirm() {
    if (!cropper) return;
    cropper
        .getCroppedCanvas({ width: props.outputSize, height: props.outputSize })
        .toBlob(
            (blob) => {
                emit('cropped', blob);
                close();
            },
            'image/jpeg',
            0.92
        );
}
</script>

<template>
    <Modal :model-value="modelValue" title="Crop Image" size="md" @update:model-value="close">
        <div class="max-h-[60vh] overflow-hidden bg-slate-100 rounded-md">
            <img ref="imageEl" :src="objectUrl" alt="Crop preview" class="block max-w-full" />
        </div>
        <p class="mt-3 text-xs text-slate-500">Drag to reposition, resize the box to adjust the crop. Output: {{ outputSize }}×{{ outputSize }}px.</p>
        <template #footer>
            <button type="button" class="px-4 py-2 text-sm rounded-md bg-[#f24c17] text-onbrand hover:bg-[#d8430f]" @click="close">Cancel</button>
            <button type="button" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover" @click="confirm">
                Crop &amp; Use
            </button>
        </template>
    </Modal>
</template>
