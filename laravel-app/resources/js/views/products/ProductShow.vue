<script setup>
import { onMounted, ref } from 'vue';
import { RouterLink } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import ProductThumbnail from '@/components/common/ProductThumbnail.vue';
import Icon from '@/components/common/Icon.vue';
import productsApi from '@/services/products';
import { useAuthStore } from '@/stores/auth';
import { can } from '@/utils/permissions';
import { formatCurrency, formatDate } from '@/utils/format';

const props = defineProps({ id: { type: [String, Number], required: true } });
const auth = useAuthStore();
const canManage = can(auth.roleSlug, 'products.manage');

const product = ref(null);
const loading = ref(true);

onMounted(async () => {
    const { data } = await productsApi.get(props.id);
    product.value = data.data;
    loading.value = false;
});
</script>

<template>
    <AppLayout>
        <LoadingSpinner v-if="loading" />
        <template v-else-if="product">
            <div class="flex items-center justify-between mb-4">
                <h1 class="text-lg font-semibold text-slate-900">{{ product.name }}</h1>
                <div class="flex gap-3">
                    <RouterLink :to="{ name: 'products.stock-history', params: { id } }" class="px-4 py-2 text-sm rounded-md border border-slate-300">
                        Stock History
                    </RouterLink>
                    <RouterLink v-if="canManage" :to="{ name: 'products.edit', params: { id } }" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover">
                        Edit
                    </RouterLink>
                    <RouterLink
                        :to="{ name: 'products.index' }"
                        class="inline-flex items-center gap-1.5 px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover"
                    >
                        <Icon name="arrow-left" class="h-4 w-4" />
                        Back
                    </RouterLink>
                </div>
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6 max-w-2xl mb-6 flex items-start gap-4">
                <ProductThumbnail :src="product.image_url" :alt="product.name" size="h-28 w-28" />
                <div v-if="product.images?.length > 1" class="flex flex-wrap gap-2">
                    <img
                        v-for="image in product.images"
                        :key="image.id"
                        :src="image.url"
                        :alt="product.name"
                        class="h-12 w-12 rounded-md object-cover border"
                        :class="image.is_default ? 'border-accent-solid' : 'border-slate-200'"
                    />
                </div>
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6 max-w-2xl">
                <dl class="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-4 text-sm">
                    <div><dt class="text-slate-400">Brand</dt><dd class="text-slate-800 font-medium">{{ product.brand?.name }}</dd></div>
                    <div><dt class="text-slate-400">Status</dt><dd><StatusBadge :status="product.status?.slug" /></dd></div>
                    <div><dt class="text-slate-400">Barcode</dt><dd class="text-slate-800 font-medium">{{ product.barcode || '—' }}</dd></div>
                    <div><dt class="text-slate-400">Purchase Price</dt><dd class="text-slate-800 font-medium">{{ formatCurrency(product.purchase_price) }}</dd></div>
                    <div><dt class="text-slate-400">Selling Price</dt><dd class="text-slate-800 font-medium">{{ formatCurrency(product.selling_price) }}</dd></div>
                    <div>
                        <dt class="text-slate-400">Current Stock</dt>
                        <dd class="font-semibold" :class="product.stock_state !== 'in-stock' ? 'text-amber-600' : 'text-slate-800'">
                            {{ product.current_stock }}
                            <StatusBadge v-if="product.stock_state !== 'in-stock'" :status="product.stock_state" class="ml-1" />
                        </dd>
                    </div>
                    <div><dt class="text-slate-400">Minimum Stock</dt><dd class="text-slate-800 font-medium">{{ product.minimum_stock }}</dd></div>
                    <div class="sm:col-span-2"><dt class="text-slate-400">Description</dt><dd class="text-slate-700">{{ product.description || '—' }}</dd></div>
                    <div><dt class="text-slate-400">Created</dt><dd class="text-slate-700">{{ formatDate(product.created_at) }}</dd></div>
                </dl>
            </div>
        </template>
    </AppLayout>
</template>
