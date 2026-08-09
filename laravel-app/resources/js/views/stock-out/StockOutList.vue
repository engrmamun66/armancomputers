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
import stockOutsApi from '@/services/stockOuts';
import lookups from '@/services/lookups';
import { useAuthStore } from '@/stores/auth';
import { can } from '@/utils/permissions';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import { formatCurrency, formatDate, formatDateTime } from '@/utils/format';

const auth = useAuthStore();
const canManage = can(auth.roleSlug, 'stock-out.manage') && auth.roleSlug !== 'staff';
const toast = useToast();
const { confirm } = useConfirm();

const columns = [
    { key: 'index', label: '#' },
    { key: 'reference_no', label: 'Reference No' },
    { key: 'sale_date', label: 'Date' },
    { key: 'customer', label: 'Customer' },
    { key: 'items_count', label: 'Items', align: 'center' },
    { key: 'total_qty', label: 'Total Qty', align: 'right' },
    { key: 'grand_total', label: 'Total Amount', align: 'right' },
    { key: 'paid_amount', label: 'Paid', align: 'right' },
    { key: 'due_amount', label: 'Due', align: 'right' },
    { key: 'status', label: 'Status' },
    { key: 'created_by', label: 'Created By' },
    { key: 'actions', label: 'Actions', align: 'right' },
];

const rows = ref([]);
const meta = ref({ current_page: 1, last_page: 1, total: 0, per_page: 15 });
const loading = ref(false);
const statuses = ref([]);
const filters = reactive({ search: '', date_from: '', date_to: '', status_id: '', payment_status: '', page: 1 });

async function loadStatuses() {
    const { data } = await lookups.statuses('stock_out');
    statuses.value = data.data;
}

async function loadStockOuts() {
    loading.value = true;
    try {
        const { data } = await stockOutsApi.list({
            search: filters.search || undefined,
            date_from: filters.date_from || undefined,
            date_to: filters.date_to || undefined,
            status_id: filters.status_id || undefined,
            payment_status: filters.payment_status || undefined,
            page: filters.page,
        });
        rows.value = data.data;
        meta.value = data.meta;
    } catch {
        toast.error('Failed to load Stock Out records.');
    } finally {
        loading.value = false;
    }
}

function hasActiveFilters() {
    return !!(filters.search || filters.date_from || filters.date_to || filters.status_id || filters.payment_status);
}

function clearFilters() {
    Object.assign(filters, { search: '', date_from: '', date_to: '', status_id: '', payment_status: '', page: 1 });
}

watch(
    [() => filters.search, () => filters.date_from, () => filters.date_to, () => filters.status_id, () => filters.payment_status],
    () => {
        filters.page = 1;
        loadStockOuts();
    }
);

onMounted(async () => {
    await loadStatuses();
    await loadStockOuts();
});

async function removeStockOut(stockOut) {
    const ok = await confirm({
        title: 'Delete this Stock Out?',
        message: `${stockOut.reference_no} will be cancelled, its stock returned, and its invoice voided. This cannot be undone.`,
        confirmText: 'Delete',
    });
    if (!ok) return;

    try {
        await stockOutsApi.remove(stockOut.id);
        toast.success('Stock Out deleted successfully.');
        await loadStockOuts();
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to delete Stock Out.');
    }
}
</script>

<template>
    <AppLayout>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
            <h1 class="text-lg font-semibold text-slate-900">Stock Out</h1>
            <RouterLink :to="{ name: 'stock-out.create' }" class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700">
                + Add Stock Out
            </RouterLink>
        </div>

        <div class="flex flex-col sm:flex-row flex-wrap gap-3 mb-4">
            <div class="sm:w-64">
                <SearchInput v-model="filters.search" placeholder="Search reference, customer, or product…" />
            </div>
            <DateRangePicker v-model:from="filters.date_from" v-model:to="filters.date_to" />
            <select v-model="filters.status_id" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Statuses</option>
                <option v-for="status in statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
            </select>
            <select v-model="filters.payment_status" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                <option value="">All Payment Statuses</option>
                <option value="paid">Paid</option>
                <option value="partial">Partial</option>
                <option value="due">Due</option>
            </select>
            <button v-if="hasActiveFilters()" type="button" class="text-sm text-blue-600 hover:text-blue-700" @click="clearFilters">
                Reset Filters
            </button>
        </div>

        <LoadingSpinner v-if="loading" />
        <EmptyState
            v-else-if="!rows.length"
            title="No Stock Out records found."
            :message="hasActiveFilters() ? 'No records match your current filters.' : ''"
            :show-clear="hasActiveFilters()"
            @clear="clearFilters"
        />
        <template v-else>
            <DataTable :columns="columns" :rows="rows" row-key="id">
                <template #cell-index="{ index }">{{ (meta.current_page - 1) * meta.per_page + index + 1 }}</template>
                <template #cell-reference_no="{ row }">
                    <RouterLink :to="{ name: 'stock-out.show', params: { id: row.id } }" class="font-medium text-blue-600 hover:text-blue-700">
                        {{ row.reference_no }}
                    </RouterLink>
                </template>
                <template #cell-sale_date="{ row }">{{ formatDate(row.sale_date) }}</template>
                <template #cell-customer="{ row }">{{ row.customer?.name }}</template>
                <template #cell-grand_total="{ row }">{{ formatCurrency(row.grand_total) }}</template>
                <template #cell-paid_amount="{ row }">{{ formatCurrency(row.paid_amount) }}</template>
                <template #cell-due_amount="{ row }">
                    <span :class="row.due_amount > 0 ? 'text-rose-600 font-medium' : ''">{{ formatCurrency(row.due_amount) }}</span>
                </template>
                <template #cell-status="{ row }">
                    <div class="flex flex-col gap-1 items-start">
                        <StatusBadge :status="row.status?.slug" />
                        <StatusBadge :status="row.payment_status" />
                    </div>
                </template>
                <template #cell-actions="{ row }">
                    <div class="flex justify-end gap-3 text-sm">
                        <RouterLink :to="{ name: 'stock-out.show', params: { id: row.id } }" class="text-slate-500 hover:text-slate-700">View</RouterLink>
                        <RouterLink v-if="canManage" :to="{ name: 'stock-out.edit', params: { id: row.id } }" class="text-blue-600 hover:text-blue-700">Edit</RouterLink>
                        <button v-if="canManage" type="button" class="text-rose-600 hover:text-rose-700" @click="removeStockOut(row)">Delete</button>
                    </div>
                </template>
            </DataTable>

            <div class="md:hidden space-y-3">
                <div v-for="row in rows" :key="row.id" class="bg-white border border-slate-200 rounded-lg p-4">
                    <div class="flex items-center justify-between">
                        <RouterLink :to="{ name: 'stock-out.show', params: { id: row.id } }" class="font-medium text-slate-900">{{ row.reference_no }}</RouterLink>
                        <StatusBadge :status="row.payment_status" />
                    </div>
                    <p class="text-sm text-slate-500 mt-1">Customer: {{ row.customer?.name }}</p>
                    <p class="text-sm text-slate-500">Date: {{ formatDate(row.sale_date) }}</p>
                    <p class="text-sm text-slate-500">Items: {{ row.items_count }} · Total: {{ formatCurrency(row.grand_total) }}</p>
                    <p class="text-sm text-slate-500">
                        Paid: {{ formatCurrency(row.paid_amount) }} · Due:
                        <span :class="row.due_amount > 0 ? 'text-rose-600 font-medium' : ''">{{ formatCurrency(row.due_amount) }}</span>
                    </p>
                    <div class="flex gap-3 mt-3 text-sm">
                        <RouterLink v-if="canManage" :to="{ name: 'stock-out.edit', params: { id: row.id } }" class="text-blue-600">Edit</RouterLink>
                        <button v-if="canManage" type="button" class="text-rose-600" @click="removeStockOut(row)">Delete</button>
                    </div>
                </div>
            </div>

            <Pagination :meta="meta" @change="(page) => { filters.page = page; loadStockOuts(); }" />
        </template>
    </AppLayout>
</template>
