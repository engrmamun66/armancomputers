<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import { RouterLink } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import DataTable from '@/components/tables/DataTable.vue';
import Pagination from '@/components/common/Pagination.vue';
import SearchInput from '@/components/common/SearchInput.vue';
import DateRangePicker from '@/components/common/DateRangePicker.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import EmptyState from '@/components/common/EmptyState.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import stockInsApi from '@/services/stockIns';
import lookups from '@/services/lookups';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import { formatCurrency, formatDate, formatDateTime } from '@/utils/format';

const toast = useToast();
const { confirm } = useConfirm();

const columns = [
    { key: 'index', label: '#' },
    { key: 'reference_no', label: 'Reference No' },
    { key: 'purchase_date', label: 'Date' },
    { key: 'supplier_name', label: 'Supplier' },
    { key: 'items_count', label: 'Items', align: 'center' },
    { key: 'total_qty', label: 'Total Qty', align: 'right' },
    { key: 'grand_total', label: 'Total Amount', align: 'right' },
    { key: 'status', label: 'Status' },
    { key: 'created_by', label: 'Created By' },
    { key: 'created_at', label: 'Created At' },
    { key: 'actions', label: 'Actions', align: 'right' },
];

const rows = ref([]);
const meta = ref({ current_page: 1, last_page: 1, total: 0, per_page: 15 });
const loading = ref(false);
const statuses = ref([]);
const filters = reactive({ search: '', date_from: '', date_to: '', status_id: '', page: 1 });

async function loadStatuses() {
    const { data } = await lookups.statuses('stock_in');
    statuses.value = data.data;
}

async function loadStockIns() {
    loading.value = true;
    try {
        const { data } = await stockInsApi.list({
            search: filters.search || undefined,
            date_from: filters.date_from || undefined,
            date_to: filters.date_to || undefined,
            status_id: filters.status_id || undefined,
            page: filters.page,
        });
        rows.value = data.data;
        meta.value = data.meta;
    } catch {
        toast.error('Failed to load Stock In records.');
    } finally {
        loading.value = false;
    }
}

function hasActiveFilters() {
    return !!(filters.search || filters.date_from || filters.date_to || filters.status_id);
}

function clearFilters() {
    Object.assign(filters, { search: '', date_from: '', date_to: '', status_id: '', page: 1 });
}

watch([() => filters.search, () => filters.date_from, () => filters.date_to, () => filters.status_id], () => {
    filters.page = 1;
    loadStockIns();
});

onMounted(async () => {
    await loadStatuses();
    await loadStockIns();
});

async function removeStockIn(stockIn) {
    const ok = await confirm({
        title: 'Delete this Stock In?',
        message: `${stockIn.reference_no} will be cancelled and its stock effect reversed. This cannot be undone.`,
        confirmText: 'Delete',
    });
    if (!ok) return;

    try {
        await stockInsApi.remove(stockIn.id);
        toast.success('Stock In deleted successfully.');
        await loadStockIns();
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to delete Stock In.');
    }
}
</script>

<template>
    <AppLayout>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
            <h1 class="text-lg font-semibold text-slate-900">Stock In</h1>
            <RouterLink :to="{ name: 'stock-in.create' }" class="px-4 py-2 text-sm font-medium text-white bg-primary-600 rounded-md hover:bg-primary-700">
                + Add Stock In
            </RouterLink>
        </div>

        <div class="flex flex-col sm:flex-row flex-wrap gap-3 mb-4">
            <div class="sm:w-64">
                <SearchInput v-model="filters.search" placeholder="Search reference or supplier…" />
            </div>
            <DateRangePicker v-model:from="filters.date_from" v-model:to="filters.date_to" />
            <select v-model="filters.status_id" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Statuses</option>
                <option v-for="status in statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
            </select>
            <button v-if="hasActiveFilters()" type="button" class="text-sm text-primary-600 hover:text-primary-700" @click="clearFilters">
                Reset Filters
            </button>
        </div>

        <LoadingSpinner v-if="loading" />
        <EmptyState
            v-else-if="!rows.length"
            title="No Stock In records found."
            :message="hasActiveFilters() ? 'No records match your current filters.' : ''"
            :show-clear="hasActiveFilters()"
            @clear="clearFilters"
        />
        <template v-else>
            <DataTable :columns="columns" :rows="rows" row-key="id">
                <template #cell-index="{ index }">{{ (meta.current_page - 1) * meta.per_page + index + 1 }}</template>
                <template #cell-reference_no="{ row }">
                    <RouterLink :to="{ name: 'stock-in.show', params: { id: row.id } }" class="font-medium text-primary-600 hover:text-primary-700">
                        {{ row.reference_no }}
                    </RouterLink>
                </template>
                <template #cell-purchase_date="{ row }">{{ formatDate(row.purchase_date) }}</template>
                <template #cell-supplier_name="{ row }">{{ row.supplier_name || '—' }}</template>
                <template #cell-grand_total="{ row }">{{ formatCurrency(row.grand_total) }}</template>
                <template #cell-status="{ row }"><StatusBadge :status="row.status?.slug" /></template>
                <template #cell-created_at="{ row }">{{ formatDateTime(row.created_at) }}</template>
                <template #cell-actions="{ row }">
                    <div class="flex justify-end gap-3 text-sm">
                        <RouterLink :to="{ name: 'stock-in.show', params: { id: row.id } }" class="text-slate-500 hover:text-slate-700">View</RouterLink>
                        <RouterLink :to="{ name: 'stock-in.edit', params: { id: row.id } }" class="text-primary-600 hover:text-primary-700">Edit</RouterLink>
                        <button type="button" class="text-rose-600 hover:text-rose-700" @click="removeStockIn(row)">Delete</button>
                    </div>
                </template>
            </DataTable>

            <div class="md:hidden space-y-3">
                <div v-for="row in rows" :key="row.id" class="bg-white border border-slate-200 rounded-lg p-4">
                    <div class="flex items-center justify-between">
                        <RouterLink :to="{ name: 'stock-in.show', params: { id: row.id } }" class="font-medium text-slate-900">{{ row.reference_no }}</RouterLink>
                        <StatusBadge :status="row.status?.slug" />
                    </div>
                    <p class="text-sm text-slate-500 mt-1">Supplier: {{ row.supplier_name || '—' }}</p>
                    <p class="text-sm text-slate-500">Date: {{ formatDate(row.purchase_date) }}</p>
                    <p class="text-sm text-slate-500">Items: {{ row.items_count }} · Total: {{ formatCurrency(row.grand_total) }}</p>
                    <div class="flex gap-3 mt-3 text-sm">
                        <RouterLink :to="{ name: 'stock-in.edit', params: { id: row.id } }" class="text-primary-600">Edit</RouterLink>
                        <button type="button" class="text-rose-600" @click="removeStockIn(row)">Delete</button>
                    </div>
                </div>
            </div>

            <Pagination :meta="meta" @change="(page) => { filters.page = page; loadStockIns(); }" />
        </template>
    </AppLayout>
</template>
