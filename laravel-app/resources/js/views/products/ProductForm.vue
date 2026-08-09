<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { RouterLink, useRouter } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import productsApi from '@/services/products';
import brandsApi from '@/services/brands';
import lookups from '@/services/lookups';
import { useToast } from '@/composables/useToast';

const props = defineProps({ id: { type: [String, Number], default: null } });
const router = useRouter();
const toast = useToast();

const isEdit = computed(() => !!props.id);
const loading = ref(true);
const saving = ref(false);
const brands = ref([]);
const statuses = ref([]);
const currentStock = ref(null);
const errors = ref({});

const form = reactive({
    brand_id: '',
    name: '',
    sku: '',
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
            sku: product.sku,
            barcode: product.barcode,
            description: product.description,
            purchase_price: product.purchase_price,
            selling_price: product.selling_price,
            minimum_stock: product.minimum_stock,
            status_id: product.status?.id,
        });
        currentStock.value = product.current_stock;
    } else {
        form.status_id = statuses.value[0]?.id ?? '';
    }

    loading.value = false;
});

async function submit() {
    saving.value = true;
    errors.value = {};
    try {
        if (isEdit.value) {
            await productsApi.update(props.id, form);
            toast.success('Product updated successfully.');
        } else {
            await productsApi.create(form);
            toast.success('Product created successfully.');
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
        <h1 class="text-lg font-semibold text-slate-900 mb-4">{{ isEdit ? 'Edit Product' : 'Add Product' }}</h1>

        <LoadingSpinner v-if="loading" />
        <form v-else class="bg-white border border-slate-200 rounded-lg p-6 max-w-2xl space-y-4" @submit.prevent="submit">
            <div v-if="isEdit" class="rounded-md bg-slate-50 border border-slate-200 px-4 py-3 text-sm text-slate-600 flex items-center justify-between">
                <span>Current stock: <strong>{{ currentStock }}</strong> (managed via Stock In / Stock Out, not editable here)</span>
                <RouterLink :to="{ name: 'products.stock-history', params: { id } }" class="text-blue-600 hover:text-blue-700 font-medium">View History</RouterLink>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Brand</label>
                    <select v-model="form.brand_id" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md">
                        <option value="" disabled>Select a brand</option>
                        <option v-for="brand in brands" :key="brand.id" :value="brand.id">{{ brand.name }}</option>
                    </select>
                    <p v-if="errors.brand_id" class="mt-1 text-xs text-rose-600">{{ errors.brand_id[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Status</label>
                    <select v-model="form.status_id" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md">
                        <option v-for="status in statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
                    </select>
                </div>
            </div>

            <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">Product Name</label>
                <input v-model="form.name" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                <p v-if="errors.name" class="mt-1 text-xs text-rose-600">{{ errors.name[0] }}</p>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">SKU</label>
                    <input v-model="form.sku" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="errors.sku" class="mt-1 text-xs text-rose-600">{{ errors.sku[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Barcode</label>
                    <input v-model="form.barcode" type="text" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="errors.barcode" class="mt-1 text-xs text-rose-600">{{ errors.barcode[0] }}</p>
                </div>
            </div>

            <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">Description</label>
                <textarea v-model="form.description" rows="3" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md"></textarea>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Purchase Price</label>
                    <input v-model="form.purchase_price" type="number" step="0.01" min="0" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="errors.purchase_price" class="mt-1 text-xs text-rose-600">{{ errors.purchase_price[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Selling Price</label>
                    <input v-model="form.selling_price" type="number" step="0.01" min="0" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="errors.selling_price" class="mt-1 text-xs text-rose-600">{{ errors.selling_price[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Minimum Stock</label>
                    <input v-model="form.minimum_stock" type="number" min="0" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="errors.minimum_stock" class="mt-1 text-xs text-rose-600">{{ errors.minimum_stock[0] }}</p>
                </div>
            </div>

            <div class="flex justify-end gap-3 pt-2">
                <RouterLink :to="{ name: 'products.index' }" class="px-4 py-2 text-sm rounded-md border border-slate-300">Cancel</RouterLink>
                <button type="submit" :disabled="saving" class="px-4 py-2 text-sm rounded-md bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-60">
                    {{ saving ? 'Saving…' : 'Save' }}
                </button>
            </div>
        </form>
    </AppLayout>
</template>
