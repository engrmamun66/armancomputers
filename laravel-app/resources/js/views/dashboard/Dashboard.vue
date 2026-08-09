<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import { RouterLink } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import EmptyState from '@/components/common/EmptyState.vue';
import DateRangePicker from '@/components/common/DateRangePicker.vue';
import StatCard from '@/components/dashboard/StatCard.vue';
import StockMovementChart from '@/components/dashboard/StockMovementChart.vue';
import SalesOverviewChart from '@/components/dashboard/SalesOverviewChart.vue';
import TopProductsChart from '@/components/dashboard/TopProductsChart.vue';
import dashboardApi from '@/services/dashboard';
import { useToast } from '@/composables/useToast';
import { formatCurrency, formatDate } from '@/utils/format';

const toast = useToast();
const loading = ref(true);
const data = ref(null);
const range = ref('month');
const customFrom = ref('');
const customTo = ref('');

const RANGE_OPTIONS = [
    { value: 'today', label: 'Today' },
    { value: 'week', label: 'This Week' },
    { value: 'month', label: 'This Month' },
    { value: 'year', label: 'This Year' },
    { value: 'custom', label: 'Custom Range' },
];

async function load() {
    loading.value = true;
    try {
        const params = { range: range.value };
        if (range.value === 'custom') {
            params.date_from = customFrom.value || undefined;
            params.date_to = customTo.value || undefined;
        }
        const { data: res } = await dashboardApi.get(params);
        data.value = res.data;
    } catch {
        toast.error('Failed to load dashboard data.');
    } finally {
        loading.value = false;
    }
}

watch(range, () => {
    if (range.value !== 'custom') load();
});
watch([customFrom, customTo], () => {
    if (range.value === 'custom' && customFrom.value && customTo.value) load();
});

onMounted(load);
</script>

<template>
    <AppLayout>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
            <h1 class="text-lg font-semibold text-slate-900">Dashboard</h1>
            <div class="flex flex-wrap items-center gap-3">
                <select v-model="range" class="px-3 py-2 text-sm border border-slate-300 rounded-md">
                    <option v-for="opt in RANGE_OPTIONS" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
                </select>
                <DateRangePicker v-if="range === 'custom'" v-model:from="customFrom" v-model:to="customTo" />
            </div>
        </div>

        <LoadingSpinner v-if="loading" />
        <template v-else-if="data">
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
                <StatCard label="Total Products" :value="data.cards.total_products" icon="box" />
                <StatCard label="Total Stock Quantity" :value="data.cards.total_stock_quantity" icon="box" />
                <StatCard label="Purchase (period)" :value="data.cards.total_purchases" icon="arrow-down-tray" />
                <StatCard label="Sales (period)" :value="data.cards.total_sales" icon="arrow-up-tray" />
                <StatCard label="Today's Sales" :value="formatCurrency(data.cards.todays_sales)" icon="document-text" />
                <StatCard label="Today's Purchase" :value="formatCurrency(data.cards.todays_purchases)" icon="arrow-down-tray" />
                <StatCard label="Total Customers" :value="data.cards.total_customers" icon="user-group" />
                <StatCard label="Low Stock Products" :value="data.cards.low_stock_products" icon="tag" tone="warning" />
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
                <div class="bg-white border border-slate-200 rounded-lg p-4">
                    <h2 class="text-sm font-semibold text-slate-700 mb-3">Purchase vs Sales</h2>
                    <StockMovementChart :points="data.stock_movement" />
                </div>
                <div class="bg-white border border-slate-200 rounded-lg p-4">
                    <h2 class="text-sm font-semibold text-slate-700 mb-3">Sales Overview</h2>
                    <SalesOverviewChart :points="data.sales_overview" />
                </div>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
                <div class="bg-white border border-slate-200 rounded-lg p-4">
                    <h2 class="text-sm font-semibold text-slate-700 mb-3">Top Selling Products</h2>
                    <EmptyState v-if="!data.top_selling_products.length" title="No sales in this period yet." />
                    <TopProductsChart v-else :products="data.top_selling_products" />
                </div>
                <div class="bg-white border border-slate-200 rounded-lg p-4">
                    <h2 class="text-sm font-semibold text-slate-700 mb-3">Low Stock Products</h2>
                    <EmptyState v-if="!data.low_stock_products.length" title="Nothing needs restocking." />
                    <div v-else class="divide-y divide-slate-100">
                        <RouterLink
                            v-for="product in data.low_stock_products"
                            :key="product.id"
                            :to="{ name: 'products.show', params: { id: product.id } }"
                            class="flex items-center justify-between py-2 text-sm hover:bg-slate-50 px-1 -mx-1 rounded"
                        >
                            <span class="text-slate-700">{{ product.name }} <span class="text-slate-400">· {{ product.sku }}</span></span>
                            <span :class="product.current_stock <= 0 ? 'text-rose-600' : 'text-amber-600'" class="font-medium">
                                {{ product.current_stock }} / {{ product.minimum_stock }}
                            </span>
                        </RouterLink>
                    </div>
                </div>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div class="bg-white border border-slate-200 rounded-lg p-4">
                    <h2 class="text-sm font-semibold text-slate-700 mb-3">Recent Purchase</h2>
                    <EmptyState v-if="!data.recent_purchases.length" title="No Purchase records yet." />
                    <div v-else class="divide-y divide-slate-100">
                        <RouterLink
                            v-for="item in data.recent_purchases"
                            :key="item.id"
                            :to="{ name: 'purchases.show', params: { id: item.id } }"
                            class="flex items-center justify-between py-2 text-sm hover:bg-slate-50 px-1 -mx-1 rounded"
                        >
                            <span class="text-slate-700">{{ item.reference_no }} <span class="text-slate-400">· {{ item.supplier_name || '—' }}</span></span>
                            <span class="text-slate-500">{{ formatCurrency(item.grand_total) }}</span>
                        </RouterLink>
                    </div>
                </div>
                <div class="bg-white border border-slate-200 rounded-lg p-4">
                    <h2 class="text-sm font-semibold text-slate-700 mb-3">Recent Sales</h2>
                    <EmptyState v-if="!data.recent_sales.length" title="No Sales records yet." />
                    <div v-else class="divide-y divide-slate-100">
                        <RouterLink
                            v-for="item in data.recent_sales"
                            :key="item.id"
                            :to="{ name: 'sales.show', params: { id: item.id } }"
                            class="flex items-center justify-between py-2 text-sm hover:bg-slate-50 px-1 -mx-1 rounded"
                        >
                            <span class="text-slate-700">{{ item.reference_no }} <span class="text-slate-400">· {{ item.customer_name }}</span></span>
                            <span class="text-slate-500">{{ formatCurrency(item.grand_total) }}</span>
                        </RouterLink>
                    </div>
                </div>
            </div>
        </template>
    </AppLayout>
</template>
