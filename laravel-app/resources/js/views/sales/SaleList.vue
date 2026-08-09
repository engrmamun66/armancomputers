<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import { RouterLink } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import DataTable from '@/components/tables/DataTable.vue';
import Icon from '@/components/common/Icon.vue';
import Pagination from '@/components/common/Pagination.vue';
import SearchInput from '@/components/common/SearchInput.vue';
import DateRangePicker from '@/components/common/DateRangePicker.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import EmptyState from '@/components/common/EmptyState.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import salesApi from '@/services/sales';
import lookups from '@/services/lookups';
import { useAuthStore } from '@/stores/auth';
import { can } from '@/utils/permissions';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import { formatCurrency, formatDate, formatDateTime, formatWarranty } from '@/utils/format';

const auth = useAuthStore();
const canManage = can(auth.roleSlug, 'sales.manage') && auth.roleSlug !== 'staff';
const toast = useToast();
const { confirm } = useConfirm();

const DATE_RANGE_PRESETS = ['This Week', 'Last Week', 'This Month', 'Last Month', 'This Year', 'Last Year'];

const columns = [
    { key: 'index', label: '#' },
    { key: 'reference_no', label: 'Reference No' },
    { key: 'sale_date', label: 'Date' },
    { key: 'customer', label: 'Customer' },
    { key: 'total_qty', label: 'Items / Qty', align: 'right' },
    { key: 'grand_total', label: 'Total Amount', align: 'right' },
    { key: 'payment', label: 'Payment', align: 'right', sortable: false },
    { key: 'warranty', label: 'Warranty', sortable: false },
    { key: 'status', label: 'Status' },
    { key: 'actions', label: 'Actions', align: 'right' },
];

const rows = ref([]);
const meta = ref({ current_page: 1, last_page: 1, total: 0, per_page: 15 });
const totals = ref({ items_count: 0, total_qty: 0, total_amount: 0 });
const loading = ref(false);
const statuses = ref([]);
const filters = reactive({ search: '', date_from: '', date_to: '', status_id: '', payment_status: '', sort_by: 'sale_date', sort_dir: 'desc', page: 1 });

async function loadStatuses() {
    const { data } = await lookups.statuses('sale');
    statuses.value = data.data;
}

async function loadSales() {
    loading.value = true;
    try {
        const { data } = await salesApi.list({
            search: filters.search || undefined,
            date_from: filters.date_from || undefined,
            date_to: filters.date_to || undefined,
            status_id: filters.status_id || undefined,
            payment_status: filters.payment_status || undefined,
            sort_by: filters.sort_by,
            sort_dir: filters.sort_dir,
            page: filters.page,
        });
        rows.value = data.data;
        meta.value = data.meta;
        totals.value = data.totals;
    } catch {
        toast.error('Failed to load Sales records.');
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
    loadSales();
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
        loadSales();
    }
);

onMounted(async () => {
    await loadStatuses();
    await loadSales();
});

async function removeSale(sale) {
    const ok = await confirm({
        title: 'Delete this Sale?',
        message: `${sale.reference_no} will be cancelled, its stock returned, and its invoice voided. This cannot be undone.`,
        confirmText: 'Delete',
    });
    if (!ok) return;

    try {
        await salesApi.remove(sale.id);
        toast.success('Sale deleted successfully.');
        await loadSales();
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to delete Sale.');
    }
}
</script>

<template>
    <AppLayout>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
            <h1 class="text-lg font-semibold text-slate-900">Sales</h1>
            <RouterLink :to="{ name: 'sales.create' }" class="px-4 py-2 text-sm font-medium text-on-accent-solid bg-accent-solid rounded-md hover:bg-accent-solid-hover">
                + Add Sale
            </RouterLink>
        </div>

        <div class="flex flex-col sm:flex-row flex-wrap gap-3 mb-4">
            <div class="sm:w-64">
                <SearchInput v-model="filters.search" placeholder="Search reference, customer, or product…" />
            </div>
            <DateRangePicker v-model:from="filters.date_from" v-model:to="filters.date_to" unified :presets="DATE_RANGE_PRESETS" />
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
            <button v-if="hasActiveFilters()" type="button" class="px-3 py-2 text-sm rounded-md bg-[#f24c17] text-white hover:bg-[#d8430f]" @click="clearFilters">
                Reset Filters
            </button>
        </div>

        <LoadingSpinner v-if="loading" />
        <EmptyState
            v-else-if="!rows.length"
            title="No Sales records found."
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
                        <td class="px-4 py-3 text-right">{{ totals.items_count }} / {{ totals.total_qty }}</td>
                        <td class="px-4 py-3 text-right">{{ formatCurrency(totals.total_amount) }}</td>
                        <td class="px-4 py-3" colspan="4"></td>
                    </tr>
                </template>
                <template #cell-reference_no="{ row }">
                    <RouterLink :to="{ name: 'sales.show', params: { id: row.id } }" class="font-medium text-link hover:text-link-hover">
                        {{ row.reference_no }}
                    </RouterLink>
                </template>
                <template #cell-sale_date="{ row }">{{ formatDate(row.sale_date) }}</template>
                <template #cell-customer="{ row }">{{ row.customer?.name }}</template>
                <template #cell-total_qty="{ row }">{{ row.items_count }} / {{ row.total_qty }}</template>
                <template #cell-grand_total="{ row }">{{ formatCurrency(row.grand_total) }}</template>
                <template #cell-payment="{ row }">
                    <div>Paid: {{ formatCurrency(row.paid_amount) }}</div>
                    <div :class="row.due_amount > 0 ? 'text-rose-600 font-medium' : 'text-slate-400'">Due: {{ formatCurrency(row.due_amount) }}</div>
                </template>
                <template #cell-warranty="{ row }">{{ formatWarranty(row.sale_date, row.warranty_end_date) || '—' }}</template>
                <template #cell-status="{ row }">
                    <div class="flex flex-col gap-1 items-start">
                        <StatusBadge :status="row.status?.slug" />
                        <StatusBadge :status="row.payment_status" />
                    </div>
                </template>
                <template #cell-actions="{ row }">
                    <div class="flex justify-end gap-1">
                        <RouterLink :to="{ name: 'sales.show', params: { id: row.id } }" title="View" class="inline-flex items-center justify-center h-8 w-8 rounded-md text-slate-600 bg-slate-200 hover:bg-slate-300">
                            <Icon name="eye" class="h-4 w-4" />
                        </RouterLink>
                        <RouterLink v-if="row.invoice_id" :to="{ name: 'invoices.show', params: { id: row.invoice_id } }" title="Invoice" class="inline-flex items-center justify-center h-8 w-8 rounded-md text-slate-600 bg-slate-200 hover:bg-slate-300">
                            <Icon name="document-text" class="h-4 w-4" />
                        </RouterLink>
                        <RouterLink v-if="canManage" :to="{ name: 'sales.edit', params: { id: row.id } }" title="Edit" class="inline-flex items-center justify-center h-8 w-8 rounded-md text-primary-700 bg-primary-50 hover:bg-primary-100">
                            <Icon name="pencil" class="h-4 w-4" />
                        </RouterLink>
                        <button v-if="canManage" type="button" title="Delete" class="inline-flex items-center justify-center h-8 w-8 rounded-md text-rose-700 bg-rose-50 hover:bg-rose-100" @click="removeSale(row)">
                            <Icon name="trash" class="h-4 w-4" />
                        </button>
                    </div>
                </template>
            </DataTable>

            <div class="md:hidden space-y-3">
                <div v-for="row in rows" :key="row.id" class="bg-white border border-slate-200 rounded-lg p-4">
                    <div class="flex items-center justify-between">
                        <RouterLink :to="{ name: 'sales.show', params: { id: row.id } }" class="font-medium text-slate-900">{{ row.reference_no }}</RouterLink>
                        <StatusBadge :status="row.payment_status" />
                    </div>
                    <p class="text-sm text-slate-500 mt-1">Customer: {{ row.customer?.name }}</p>
                    <p class="text-sm text-slate-500">Date: {{ formatDate(row.sale_date) }}</p>
                    <p class="text-sm text-slate-500">Items: {{ row.items_count }} · Total: {{ formatCurrency(row.grand_total) }}</p>
                    <p class="text-sm text-slate-500">
                        Paid: {{ formatCurrency(row.paid_amount) }} · Due:
                        <span :class="row.due_amount > 0 ? 'text-rose-600 font-medium' : ''">{{ formatCurrency(row.due_amount) }}</span>
                    </p>
                    <p class="text-sm text-slate-500">Warranty: {{ formatWarranty(row.sale_date, row.warranty_end_date) || '—' }}</p>
                    <div class="flex gap-2 mt-3 text-sm">
                        <RouterLink v-if="row.invoice_id" :to="{ name: 'invoices.show', params: { id: row.invoice_id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-slate-600 bg-slate-200">Invoice</RouterLink>
                        <RouterLink v-if="canManage" :to="{ name: 'sales.edit', params: { id: row.id } }" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-primary-700 bg-primary-50">Edit</RouterLink>
                        <button v-if="canManage" type="button" class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-rose-700 bg-rose-50" @click="removeSale(row)">Delete</button>
                    </div>
                </div>
            </div>

            <Pagination :meta="meta" @change="(page) => { filters.page = page; loadSales(); }" />
        </template>
    </AppLayout>
</template>
