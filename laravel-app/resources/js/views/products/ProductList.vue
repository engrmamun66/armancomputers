<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import { RouterLink, useRouter } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import DataTable from '@/components/tables/DataTable.vue';
import Pagination from '@/components/common/Pagination.vue';
import SearchInput from '@/components/common/SearchInput.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import EmptyState from '@/components/common/EmptyState.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import ProductThumbnail from '@/components/common/ProductThumbnail.vue';
import productsApi from '@/services/products';
import brandsApi from '@/services/brands';
import lookups from '@/services/lookups';
import { useAuthStore } from '@/stores/auth';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import { can } from '@/utils/permissions';
import { formatCurrency } from '@/utils/format';

const router = useRouter();
const auth = useAuthStore();
const toast = useToast();
const { confirm } = useConfirm();

const canManage = can(auth.roleSlug, 'products.manage');

const columns = [
    { key: 'index', label: '#' },
    { key: 'image', label: 'Image', sortable: false },
    { key: 'name', label: 'Product' },
    { key: 'barcode', label: 'Barcode' },
    { key: 'brand', label: 'Brand' },
    { key: 'purchase_price', label: 'Purchase Price', align: 'right' },
    { key: 'selling_price', label: 'Selling Price', align: 'right' },
    { key: 'current_stock', label: 'Stock', align: 'right' },
    { key: 'minimum_stock', label: 'Minimum Stock', align: 'right' },
    { key: 'status', label: 'Status' },
    { key: 'actions', label: 'Actions', align: 'right' },
];

const rows = ref([]);
const meta = ref({ current_page: 1, last_page: 1, total: 0, per_page: 15 });
const loading = ref(false);
const brands = ref([]);
const statuses = ref([]);
const filters = reactive({ search: '', brand_id: '', stock_status: '', status_id: '', sort_by: 'name', sort_dir: 'asc', page: 1 });

async function loadLookups() {
    const [brandRes, statusRes] = await Promise.all([brandsApi.all(), lookups.statuses('general')]);
    brands.value = brandRes.data.data;
    statuses.value = statusRes.data.data;
}

async function loadProducts() {
    loading.value = true;
    try {
        const { data } = await productsApi.list({
            search: filters.search || undefined,
            brand_id: filters.brand_id || undefined,
            stock_status: filters.stock_status || undefined,
            status_id: filters.status_id || undefined,
            sort_by: filters.sort_by,
            sort_dir: filters.sort_dir,
            page: filters.page,
        });
        rows.value = data.data;
        meta.value = data.meta;
    } catch {
        toast.error('Failed to load products.');
    } finally {
        loading.value = false;
    }
}

function clearFilters() {
    filters.search = '';
    filters.brand_id = '';
    filters.stock_status = '';
    filters.status_id = '';
    filters.page = 1;
}

function onSort(key) {
    if (filters.sort_by === key) {
        filters.sort_dir = filters.sort_dir === 'asc' ? 'desc' : 'asc';
    } else {
        filters.sort_by = key;
        filters.sort_dir = 'asc';
    }
    filters.page = 1;
    loadProducts();
}

const hasActiveFilters = () => !!(filters.search || filters.brand_id || filters.stock_status || filters.status_id);

watch([() => filters.search, () => filters.brand_id, () => filters.stock_status, () => filters.status_id], () => {
    filters.page = 1;
    loadProducts();
});

onMounted(async () => {
    await loadLookups();
    await loadProducts();
});

async function removeProduct(product) {
    const ok = await confirm({
        title: 'Delete this product?',
        message: `"${product.name}" will be archived. Historical stock records are preserved.`,
        confirmText: 'Delete',
    });
    if (!ok) return;

    try {
        await productsApi.remove(product.id);
        toast.success('Product deleted successfully.');
        await loadProducts();
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to delete product.');
    }
}
</script>

<template>
    <AppLayout>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
            <h1 class="text-lg font-semibold text-slate-900">Products</h1>
            <RouterLink
                v-if="canManage"
                :to="{ name: 'products.create' }"
                class="px-4 py-2 text-sm font-medium text-on-accent-solid bg-accent-solid rounded-md hover:bg-accent-solid-hover"
            >
                + Add Product
            </RouterLink>
        </div>

        <div class="flex flex-col sm:flex-row flex-wrap gap-3 mb-4">
            <div class="sm:w-64">
                <SearchInput v-model="filters.search" placeholder="Search name or barcode…" />
            </div>
            <select v-model="filters.brand_id" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Brands</option>
                <option v-for="brand in brands" :key="brand.id" :value="brand.id">{{ brand.name }}</option>
            </select>
            <select v-model="filters.stock_status" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Stock Levels</option>
                <option value="in-stock">In Stock</option>
                <option value="low-stock">Low Stock</option>
                <option value="out-of-stock">Out of Stock</option>
            </select>
            <select v-model="filters.status_id" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Statuses</option>
                <option v-for="status in statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
            </select>
        </div>

        <LoadingSpinner v-if="loading" />
        <EmptyState
            v-else-if="!rows.length"
            title="No products found."
            :message="hasActiveFilters() ? 'No records match your current filters.' : ''"
            :show-clear="hasActiveFilters()"
            @clear="clearFilters"
        />
        <template v-else>
            <DataTable :columns="columns" :rows="rows" row-key="id" :sort-by="filters.sort_by" :sort-dir="filters.sort_dir" @sort="onSort">
                <template #cell-index="{ index }">{{ (meta.current_page - 1) * meta.per_page + index + 1 }}</template>
                <template #cell-image="{ row }">
                    <ProductThumbnail :src="row.image_url" :alt="row.name" size="h-10 w-10" />
                </template>
                <template #cell-name="{ row }">
                    <RouterLink :to="{ name: 'products.show', params: { id: row.id } }" class="font-medium text-slate-800 hover:text-link">
                        {{ row.name }}
                    </RouterLink>
                </template>
                <template #cell-barcode="{ row }">{{ row.barcode || '—' }}</template>
                <template #cell-brand="{ row }">{{ row.brand?.name }}</template>
                <template #cell-purchase_price="{ row }">{{ formatCurrency(row.purchase_price) }}</template>
                <template #cell-selling_price="{ row }">{{ formatCurrency(row.selling_price) }}</template>
                <template #cell-current_stock="{ row }">
                    <span :class="row.stock_state !== 'in-stock' ? 'font-semibold text-amber-600' : ''">{{ row.current_stock }}</span>
                </template>
                <template #cell-status="{ row }">
                    <div class="flex flex-col gap-1 items-start">
                        <StatusBadge :status="row.status?.slug" />
                        <StatusBadge v-if="row.stock_state !== 'in-stock'" :status="row.stock_state" />
                    </div>
                </template>
                <template #cell-actions="{ row }">
                    <div class="flex justify-end gap-2 text-sm">
                        <RouterLink :to="{ name: 'products.stock-history', params: { id: row.id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-slate-600 bg-slate-200 hover:bg-slate-300">History</RouterLink>
                        <RouterLink v-if="canManage" :to="{ name: 'products.edit', params: { id: row.id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-primary-700 bg-primary-50 hover:bg-primary-100">Edit</RouterLink>
                        <button v-if="canManage" type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-rose-700 bg-rose-50 hover:bg-rose-100" @click="removeProduct(row)">Delete</button>
                    </div>
                </template>
            </DataTable>

            <div class="md:hidden space-y-3">
                <div v-for="row in rows" :key="row.id" class="bg-white border border-slate-200 rounded-lg p-4">
                    <div class="flex items-start gap-3">
                        <ProductThumbnail :src="row.image_url" :alt="row.name" size="h-14 w-14" />
                        <div class="flex-1 min-w-0">
                            <div class="flex items-center justify-between gap-2">
                                <RouterLink :to="{ name: 'products.show', params: { id: row.id } }" class="font-medium text-slate-900 truncate">{{ row.name }}</RouterLink>
                                <StatusBadge :status="row.status?.slug" />
                            </div>
                            <p class="text-sm text-slate-500 mt-1">{{ row.brand?.name }}</p>
                            <p class="text-sm text-slate-500">Selling: {{ formatCurrency(row.selling_price) }}</p>
                            <p class="text-sm mt-1" :class="row.stock_state !== 'in-stock' ? 'font-semibold text-amber-600' : 'text-slate-500'">
                                Stock: {{ row.current_stock }} <span v-if="row.stock_state !== 'in-stock'">({{ row.stock_state }})</span>
                            </p>
                        </div>
                    </div>
                    <div class="flex gap-2 mt-3 text-sm">
                        <RouterLink :to="{ name: 'products.stock-history', params: { id: row.id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-slate-600 bg-slate-200">History</RouterLink>
                        <RouterLink v-if="canManage" :to="{ name: 'products.edit', params: { id: row.id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-primary-700 bg-primary-50">Edit</RouterLink>
                        <button v-if="canManage" type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-rose-700 bg-rose-50" @click="removeProduct(row)">Delete</button>
                    </div>
                </div>
            </div>

            <Pagination :meta="meta" @change="(page) => { filters.page = page; loadProducts(); }" />
        </template>
    </AppLayout>
</template>
