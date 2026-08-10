<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { RouterLink, useRouter } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import productsApi from '@/services/products';
import brandsApi from '@/services/brands';
import lookups from '@/services/lookups';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import SelectSearch from '@/components/common/SelectSearch.vue';
import ProductThumbnail from '@/components/common/ProductThumbnail.vue';
import ImageCropModal from '@/components/common/ImageCropModal.vue';
import Icon from '@/components/common/Icon.vue';

const props = defineProps({ id: { type: [String, Number], default: null } });
const router = useRouter();
const toast = useToast();
const { confirm } = useConfirm();

const isEdit = computed(() => !!props.id);
const loading = ref(true);
const saving = ref(false);
const brands = ref([]);
const statuses = ref([]);
const currentStock = ref(null);
const errors = ref({});
const images = ref([]);
const uploadingImage = ref(false);
const imageInput = ref(null);

// --- create-mode pending image (cropped client-side, uploaded after the product is created) ---
const showCropModal = ref(false);
const pickedFile = ref(null);
const pendingImageBlob = ref(null);
const pendingImagePreviewUrl = ref(null);

const form = reactive({
    brand_id: '',
    name: '',
    barcode: '',
    description: '',
    purchase_price: '',
    selling_price: '',
    minimum_stock: 5,
    status_id: '',
});

onMounted(async () => {
    const [brandRes, statusRes] = await Promise.all([brandsApi.all(), lookups.statuses('general')]);
    brands.value = brandRes.data.data;
    statuses.value = statusRes.data.data;

    if (isEdit.value) {
        const { data } = await productsApi.get(props.id);
        const product = data.data;
        Object.assign(form, {
            brand_id: product.brand?.id,
            name: product.name,
            barcode: product.barcode,
            description: product.description,
            purchase_price: product.purchase_price,
            selling_price: product.selling_price,
            minimum_stock: product.minimum_stock,
            status_id: product.status?.id,
        });
        currentStock.value = product.current_stock;
        images.value = product.images || [];
    } else {
        form.status_id = statuses.value[0]?.id ?? '';
    }

    loading.value = false;
});

const brandOptions = computed(() => brands.value.map((brand) => ({ value: brand.id, label: brand.name })));
const statusOptions = computed(() => statuses.value.map((status) => ({ value: status.id, label: status.name })));

async function createBrand(name) {
    const activeStatusId = statuses.value.find((status) => status.slug === 'active')?.id;
    const { data } = await brandsApi.create({ name, status_id: activeStatusId });
    brands.value.push(data.data);
    toast.success(`Brand "${data.data.name}" added.`);
    return { value: data.data.id, label: data.data.name };
}

function pickImage() {
    imageInput.value?.click();
}

async function onImageSelected(event) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;

    if (!isEdit.value) {
        pickedFile.value = file;
        showCropModal.value = true;
        return;
    }

    uploadingImage.value = true;
    try {
        const formData = new FormData();
        formData.append('image', file);
        const { data } = await productsApi.uploadImage(props.id, formData);
        if (data.data.is_default) {
            images.value.forEach((img) => (img.is_default = false));
        }
        images.value.push(data.data);
        toast.success('Image uploaded successfully.');
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to upload image.');
    } finally {
        uploadingImage.value = false;
    }
}

function onImageCropped(blob) {
    if (pendingImagePreviewUrl.value) {
        URL.revokeObjectURL(pendingImagePreviewUrl.value);
    }
    pendingImageBlob.value = blob;
    pendingImagePreviewUrl.value = URL.createObjectURL(blob);
    pickedFile.value = null;
}

function removePendingImage() {
    if (pendingImagePreviewUrl.value) {
        URL.revokeObjectURL(pendingImagePreviewUrl.value);
    }
    pendingImageBlob.value = null;
    pendingImagePreviewUrl.value = null;
}

async function setDefaultImage(image) {
    if (image.is_default) return;
    try {
        await productsApi.setDefaultImage(props.id, image.id);
        images.value.forEach((img) => (img.is_default = img.id === image.id));
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to set default image.');
    }
}

async function removeImage(image) {
    const ok = await confirm({
        title: 'Delete this image?',
        message: 'This cannot be undone.',
        confirmText: 'Delete',
    });
    if (!ok) return;

    try {
        await productsApi.deleteImage(props.id, image.id);
        images.value = images.value.filter((img) => img.id !== image.id);
        if (image.is_default && images.value.length) {
            images.value[0].is_default = true;
        }
        toast.success('Image deleted successfully.');
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to delete image.');
    }
}

async function submit() {
    saving.value = true;
    errors.value = {};
    try {
        if (isEdit.value) {
            await productsApi.update(props.id, form);
            toast.success('Product updated successfully.');
        } else {
            const { data } = await productsApi.create(form);
            toast.success('Product created successfully.');
            if (pendingImageBlob.value) {
                try {
                    const formData = new FormData();
                    formData.append('image', pendingImageBlob.value, 'product.jpg');
                    await productsApi.uploadImage(data.data.id, formData);
                } catch {
                    toast.error('Product was created, but the image failed to upload.');
                }
            }
        }
        router.push({ name: 'products.index' });
    } catch (error) {
        if (error.response?.status === 422) {
            errors.value = error.response.data.errors || {};
        } else {
            toast.error(error.response?.data?.message || 'Something went wrong.');
        }
    } finally {
        saving.value = false;
    }
}
</script>

<template>
    <AppLayout>
        <div class="flex items-center justify-between mb-4">
            <h1 class="text-lg font-semibold text-slate-900">{{ isEdit ? 'Edit Product' : 'Add Product' }}</h1>
            <RouterLink
                :to="{ name: 'products.index' }"
                class="inline-flex items-center gap-1.5 px-3 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover"
            >
                <Icon name="arrow-left" class="h-4 w-4" />
                Back
            </RouterLink>
        </div>

        <LoadingSpinner v-if="loading" />
        <form v-else class="bg-white border border-slate-200 rounded-lg p-6 max-w-2xl space-y-4" @submit.prevent="submit">
            <div v-if="isEdit" class="rounded-md bg-slate-50 border border-slate-200 px-4 py-3 text-sm text-slate-600 flex items-center justify-between">
                <span>Current stock: <strong>{{ currentStock }}</strong> (managed via Stock In / Stock Out, not editable here)</span>
                <RouterLink :to="{ name: 'products.stock-history', params: { id } }" class="text-link hover:text-link-hover font-medium">View History</RouterLink>
            </div>

            <div v-if="isEdit">
                <div class="flex items-center justify-between mb-2">
                    <label class="block text-sm font-medium text-slate-700">Images</label>
                    <button
                        type="button"
                        :disabled="uploadingImage"
                        class="px-3 py-1.5 text-xs font-medium rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover disabled:opacity-60"
                        @click="pickImage"
                    >
                        {{ uploadingImage ? 'Uploading…' : '+ Add Image' }}
                    </button>
                    <input ref="imageInput" type="file" accept="image/*" class="hidden" @change="onImageSelected" />
                </div>
                <div v-if="!images.length" class="text-sm text-slate-400">No images yet.</div>
                <div v-else class="flex flex-wrap gap-3">
                    <div v-for="image in images" :key="image.id" class="relative group">
                        <ProductThumbnail :src="image.url" size="h-20 w-20" />
                        <span v-if="image.is_default" class="absolute -top-1.5 -left-1.5 px-1.5 py-0.5 text-[10px] font-semibold rounded bg-accent-solid text-on-accent-solid">Default</span>
                        <div class="absolute inset-0 rounded-md bg-overlay-solid/60 opacity-0 group-hover:opacity-100 flex items-center justify-center gap-1 transition-opacity">
                            <button
                                v-if="!image.is_default"
                                type="button"
                                title="Set as default"
                                class="h-6 w-6 flex items-center justify-center rounded bg-white text-slate-700 hover:bg-slate-100"
                                @click="setDefaultImage(image)"
                            >
                                <Icon name="check" class="h-3.5 w-3.5" />
                            </button>
                            <button
                                type="button"
                                title="Delete"
                                class="h-6 w-6 flex items-center justify-center rounded bg-white text-rose-600 hover:bg-rose-50"
                                @click="removeImage(image)"
                            >
                                <Icon name="trash" class="h-3.5 w-3.5" />
                            </button>
                        </div>
                    </div>
                </div>
            </div>
            <div v-else>
                <label class="block text-sm font-medium text-slate-700 mb-2">Image <span class="text-slate-400 font-normal">(optional)</span></label>
                <input ref="imageInput" type="file" accept="image/*" class="hidden" @change="onImageSelected" />
                <div v-if="!pendingImagePreviewUrl">
                    <button
                        type="button"
                        class="h-20 w-20 rounded-md border border-dashed border-slate-300 text-slate-400 hover:text-slate-600 hover:border-slate-400 flex items-center justify-center"
                        @click="pickImage"
                    >
                        <Icon name="photo" class="h-6 w-6" />
                    </button>
                </div>
                <div v-else class="relative inline-block group">
                    <img :src="pendingImagePreviewUrl" alt="Product preview" class="h-20 w-20 rounded-md object-cover border border-slate-200" />
                    <button
                        type="button"
                        title="Remove"
                        class="absolute -top-2 -right-2 h-6 w-6 flex items-center justify-center rounded-full bg-white border border-slate-200 text-rose-600 hover:bg-rose-50 shadow-sm"
                        @click="removePendingImage"
                    >
                        <Icon name="x-mark" class="h-3.5 w-3.5" />
                    </button>
                </div>
            </div>

            <ImageCropModal v-model="showCropModal" :file="pickedFile" :output-size="600" @cropped="onImageCropped" />

             <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">Product Name <span class="text-rose-600">*</span></label>
                <input v-model="form.name" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                <p v-if="errors.name" class="mt-1 text-xs text-rose-600">{{ errors.name[0] }}</p>
            </div>
            
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Brand <span class="text-rose-600">*</span></label>
                    <SelectSearch
                        v-model="form.brand_id"
                        :options="brandOptions"
                        placeholder="Select a brand"
                        allow-create
                        :create-fn="createBrand"
                        create-label="Add brand"
                    />
                    <p v-if="errors.brand_id" class="mt-1 text-xs text-rose-600">{{ errors.brand_id[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Status <span class="text-rose-600">*</span></label>
                    <SelectSearch v-model="form.status_id" :options="statusOptions" placeholder="Select a status" />
                </div>
            </div>

            <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">Barcode <span class="text-slate-400 font-normal">(optional)</span></label>
                <input v-model="form.barcode" type="text" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                <p v-if="errors.barcode" class="mt-1 text-xs text-rose-600">{{ errors.barcode[0] }}</p>
            </div>

            <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">Description</label>
                <textarea v-model="form.description" rows="3" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md"></textarea>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Purchase Price <span class="text-rose-600">*</span></label>
                    <input v-model="form.purchase_price" type="number" step="0.01" min="0" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="errors.purchase_price" class="mt-1 text-xs text-rose-600">{{ errors.purchase_price[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Selling Price <span class="text-rose-600">*</span></label>
                    <input v-model="form.selling_price" type="number" step="0.01" min="0" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="errors.selling_price" class="mt-1 text-xs text-rose-600">{{ errors.selling_price[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Minimum Stock <span class="text-rose-600">*</span></label>
                    <input v-model="form.minimum_stock" type="number" min="0" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="errors.minimum_stock" class="mt-1 text-xs text-rose-600">{{ errors.minimum_stock[0] }}</p>
                </div>
            </div>

            <div class="flex justify-end gap-3 pt-2">
                <RouterLink :to="{ name: 'products.index' }" class="px-4 py-2 text-sm rounded-md bg-[#f24c17] text-white hover:bg-[#d8430f]">Cancel</RouterLink>
                <button type="submit" :disabled="saving" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover disabled:opacity-60">
                    {{ saving ? 'Saving…' : 'Save' }}
                </button>
            </div>
        </form>
    </AppLayout>
</template>
