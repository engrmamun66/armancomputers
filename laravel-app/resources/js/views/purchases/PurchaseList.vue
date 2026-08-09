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
import purchasesApi from '@/services/purchases';
import lookups from '@/services/lookups';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import { formatCurrency, formatDate, formatDateTime, formatWarranty } from '@/utils/format';

const toast = useToast();
const { confirm } = useConfirm();

const DATE_RANGE_PRESETS = ['This Week', 'Last Week', 'This Month', 'Last Month', 'This Year', 'Last Year'];

const columns = [
    { key: 'index', label: '#' },
    { key: 'reference_no', label: 'Reference No' },
    { key: 'purchase_date', label: 'Date' },
    { key: 'supplier_name', label: 'Supplier' },
    { key: 'items_count', label: 'Items', align: 'center' },
    { key: 'total_qty', label: 'Total Qty', align: 'right' },
    { key: 'grand_total', label: 'Total Amount', align: 'right' },
    { key: 'warranty', label: 'Warranty', sortable: false },
    { key: 'status', label: 'Status' },
    { key: 'created_at', label: 'Created', sortable: false },
    { key: 'actions', label: 'Actions', align: 'right' },
];

const rows = ref([]);
const meta = ref({ current_page: 1, last_page: 1, total: 0, per_page: 15 });
const totals = ref({ items_count: 0, total_qty: 0, total_amount: 0 });
const loading = ref(false);
const statuses = ref([]);
const filters = reactive({ search: '', date_from: '', date_to: '', status_id: '', sort_by: 'purchase_date', sort_dir: 'desc', page: 1 });

async function loadStatuses() {
    const { data } = await lookups.statuses('purchase');
    statuses.value = data.data;
}

async function loadPurchases() {
    loading.value = true;
    try {
        const { data } = await purchasesApi.list({
            search: filters.search || undefined,
            date_from: filters.date_from || undefined,
            date_to: filters.date_to || undefined,
            status_id: filters.status_id || undefined,
            sort_by: filters.sort_by,
            sort_dir: filters.sort_dir,
            page: filters.page,
        });
        rows.value = data.data;
        meta.value = data.meta;
        totals.value = data.totals;
    } catch {
        toast.error('Failed to load Purchase records.');
    } finally {
        loading.value = false;
    }
}

function onSort(key) {
    if (filters.sort_by === key) {
        filters.sort_dir = filters.sort_dir === 'asc' ? 'desc' : 'asc';
    } else {
        filters.sort_by = key;
        filters.sort_dir = 'asc';
    }
    filters.page = 1;
    loadPurchases();
}

function hasActiveFilters() {
    return !!(filters.search || filters.date_from || filters.date_to || filters.status_id);
}

function clearFilters() {
    Object.assign(filters, { search: '', date_from: '', date_to: '', status_id: '', page: 1 });
}

watch([() => filters.search, () => filters.date_from, () => filters.date_to, () => filters.status_id], () => {
    filters.page = 1;
    loadPurchases();
});

onMounted(async () => {
    await loadStatuses();
    await loadPurchases();
});

async function removePurchase(purchase) {
    const ok = await confirm({
        title: 'Delete this Purchase?',
        message: `${purchase.reference_no} will be cancelled and its stock effect reversed. This cannot be undone.`,
        confirmText: 'Delete',
    });
    if (!ok) return;

    try {
        await purchasesApi.remove(purchase.id);
        toast.success('Purchase deleted successfully.');
        await loadPurchases();
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to delete Purchase.');
    }
}
</script>

<template>
    <AppLayout>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
            <h1 class="text-lg font-semibold text-slate-900">Purchase</h1>
            <RouterLink :to="{ name: 'purchases.create' }" class="px-4 py-2 text-sm font-medium text-on-accent-solid bg-accent-solid rounded-md hover:bg-accent-solid-hover">
                + Add Purchase
            </RouterLink>
        </div>

        <div class="flex flex-col sm:flex-row flex-wrap gap-3 mb-4">
            <div class="sm:w-64">
                <SearchInput v-model="filters.search" placeholder="Search reference or supplier…" />
            </div>
            <DateRangePicker v-model:from="filters.date_from" v-model:to="filters.date_to" unified :presets="DATE_RANGE_PRESETS" />
            <select v-model="filters.status_id" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Statuses</option>
                <option v-for="status in statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
            </select>
            <button v-if="hasActiveFilters()" type="button" class="text-sm text-link hover:text-link-hover" @click="clearFilters">
                Reset Filters
            </button>
        </div>

        <LoadingSpinner v-if="loading" />
        <EmptyState
            v-else-if="!rows.length"
            title="No Purchase records found."
            :message="hasActiveFilters() ? 'No records match your current filters.' : ''"
            :show-clear="hasActiveFilters()"
            @clear="clearFilters"
        />
        <template v-else>
            <DataTable :columns="columns" :rows="rows" row-key="id" :sort-by="filters.sort_by" :sort-dir="filters.sort_dir" @sort="onSort">
                <template #cell-index="{ index }">{{ (meta.current_page - 1) * meta.per_page + index + 1 }}</template>
                <template #footer>
                    <tr v-if="rows.length" class="bg-slate-50 font-semibold text-slate-700 border-t border-slate-200">
                        <td class="px-4 py-3" colspan="4">Totals</td>
                        <td class="px-4 py-3 text-center">{{ totals.items_count }}</td>
                        <td class="px-4 py-3 text-right">{{ totals.total_qty }}</td>
                        <td class="px-4 py-3 text-right">{{ formatCurrency(totals.total_amount) }}</td>
                        <td class="px-4 py-3" colspan="4"></td>
                    </tr>
                </template>
                <template #cell-reference_no="{ row }">
                    <RouterLink :to="{ name: 'purchases.show', params: { id: row.id } }" class="font-medium text-link hover:text-link-hover">
                        {{ row.reference_no }}
                    </RouterLink>
                </template>
                <template #cell-purchase_date="{ row }">{{ formatDate(row.purchase_date) }}</template>
                <template #cell-supplier_name="{ row }">{{ row.supplier_name || '—' }}</template>
                <template #cell-grand_total="{ row }">{{ formatCurrency(row.grand_total) }}</template>
                <template #cell-status="{ row }"><StatusBadge :status="row.status?.slug" /></template>
                <template #cell-created_at="{ row }">{{ formatDateTime(row.created_at) }}</template>
                <template #cell-actions="{ row }">
                    <div class="flex justify-end gap-2 text-sm">
                        <RouterLink :to="{ name: 'purchases.show', params: { id: row.id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-slate-600 bg-slate-200 hover:bg-slate-300">View</RouterLink>
                        <RouterLink :to="{ name: 'purchases.edit', params: { id: row.id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-primary-700 bg-primary-50 hover:bg-primary-100">Edit</RouterLink>
                        <button type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-rose-700 bg-rose-50 hover:bg-rose-100" @click="removePurchase(row)">Delete</button>
                    </div>
                </template>
            </DataTable>

            <div class="md:hidden space-y-3">
                <div v-for="row in rows" :key="row.id" class="bg-white border border-slate-200 rounded-lg p-4">
                    <div class="flex items-center justify-between">
                        <RouterLink :to="{ name: 'purchases.show', params: { id: row.id } }" class="font-medium text-slate-900">{{ row.reference_no }}</RouterLink>
                        <StatusBadge :status="row.status?.slug" />
                    </div>
                    <p class="text-sm text-slate-500 mt-1">Supplier: {{ row.supplier_name || '—' }}</p>
                    <p class="text-sm text-slate-500">Date: {{ formatDate(row.purchase_date) }}</p>
                    <p class="text-sm text-slate-500">Items: {{ row.items_count }} · Total: {{ formatCurrency(row.grand_total) }}</p>
                    <div class="flex gap-2 mt-3 text-sm">
                        <RouterLink :to="{ name: 'purchases.edit', params: { id: row.id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-primary-700 bg-primary-50">Edit</RouterLink>
                        <button type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-rose-700 bg-rose-50" @click="removePurchase(row)">Delete</button>
                    </div>
                </div>
            </div>

            <Pagination :meta="meta" @change="(page) => { filters.page = page; loadPurchases(); }" />
        </template>
    </AppLayout>
</template>
