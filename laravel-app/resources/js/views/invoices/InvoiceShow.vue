<script setup>
import { onMounted, ref } from 'vue';
import { RouterLink } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import StatusBadge from '@/components/common/StatusBadge.vue';
import invoicesApi from '@/services/invoices';
import { useAuthStore } from '@/stores/auth';
import { can } from '@/utils/permissions';
import { COMPANY } from '@/utils/company';
import { formatCurrency, formatDate, formatWarranty } from '@/utils/format';

const props = defineProps({ id: { type: [String, Number], required: true } });

const auth = useAuthStore();
const canManage = can(auth.roleSlug, 'sales.manage') && auth.roleSlug !== 'staff';

const invoice = ref(null);
const loading = ref(true);

onMounted(async () => {
    const { data } = await invoicesApi.get(props.id);
    invoice.value = data.data;
    loading.value = false;
});

function print() {
    window.print();
}
</script>

<template>
    <AppLayout>
        <LoadingSpinner v-if="loading" />
        <template v-else-if="invoice">
            <div class="no-print flex items-center justify-between mb-4">
                <h1 class="text-lg font-semibold text-slate-900">Invoice {{ invoice.invoice_number }}</h1>
                <div class="flex gap-3">
                    <RouterLink
                        v-if="canManage && invoice.sale_id"
                        :to="{ name: 'sales.show', params: { id: invoice.sale_id } }"
                        class="px-4 py-2 text-sm rounded-md border border-slate-300"
                    >
                        View Sale
                    </RouterLink>
                    <RouterLink
                        v-if="canManage && invoice.sale_id"
                        :to="{ name: 'sales.edit', params: { id: invoice.sale_id } }"
                        class="px-4 py-2 text-sm rounded-md border border-slate-300"
                    >
                        Edit Sale
                    </RouterLink>
                    <button type="button" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover" @click="print">Print</button>
                    <RouterLink :to="{ name: 'invoices.index' }" class="px-4 py-2 text-sm rounded-md border border-slate-300">Back</RouterLink>
                </div>
            </div>

            <div class="print-area bg-white border border-slate-200 rounded-lg p-4 sm:p-8 max-w-3xl mx-auto">
                <div class="flex items-start justify-between border-b border-slate-200 pb-6 mb-6">
                    <div>
                        <h2 class="text-xl font-bold text-slate-900">{{ COMPANY.name }}</h2>
                        <p class="text-sm text-slate-500 mt-1">{{ COMPANY.phone }} · {{ COMPANY.email }}</p>
                        <p class="text-sm text-slate-500">{{ COMPANY.address }}</p>
                    </div>
                    <div class="text-right">
                        <p class="text-lg font-semibold text-slate-900">INVOICE</p>
                        <p class="text-sm text-slate-500 mt-1">{{ invoice.invoice_number }}</p>
                        <p class="text-sm text-slate-500">{{ formatDate(invoice.invoice_date) }}</p>
                        <p v-if="invoice.warranty_end_date" class="text-sm text-slate-500">
                            Warranty: {{ formatWarranty(invoice.sale_date, invoice.warranty_end_date) }} (until {{ formatDate(invoice.warranty_end_date) }})
                        </p>
                        <div class="mt-2"><StatusBadge :status="invoice.payment_status" /></div>
                    </div>
                </div>

                <div class="mb-6">
                    <p class="text-xs uppercase tracking-wide text-slate-400 mb-1">Bill To</p>
                    <p class="font-medium text-slate-800">{{ invoice.customer?.name }}</p>
                    <p class="text-sm text-slate-500">{{ invoice.customer?.phone }}</p>
                    <p class="text-sm text-slate-500">{{ invoice.customer?.email }}</p>
                    <p class="text-sm text-slate-500">{{ invoice.customer?.address }}</p>
                </div>

                <div class="overflow-x-auto mb-6">
                    <table class="w-full text-sm min-w-[480px]">
                        <thead>
                            <tr class="text-left text-slate-500 border-b border-slate-200">
                                <th class="py-2 pr-2">#</th>
                                <th class="py-2 pr-2">Product</th>
                                <th class="py-2 pr-2 text-right">Qty</th>
                                <th class="py-2 pr-2 text-right">Unit Price</th>
                                <th class="py-2 text-right">Total</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="(item, index) in invoice.items" :key="item.id" class="border-b border-slate-100">
                                <td class="py-2 pr-2 text-slate-500">{{ index + 1 }}</td>
                                <td class="py-2 pr-2 font-medium text-slate-800">{{ item.product_name }}</td>
                                <td class="py-2 pr-2 text-right">{{ item.quantity }}</td>
                                <td class="py-2 pr-2 text-right">{{ formatCurrency(item.unit_price) }}</td>
                                <td class="py-2 text-right">{{ formatCurrency(item.total_price) }}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>

                <div class="flex justify-end">
                    <div class="w-full max-w-xs space-y-2 text-sm">
                        <div class="flex justify-between"><span class="text-slate-500">Subtotal</span><span>{{ formatCurrency(invoice.subtotal) }}</span></div>
                        <div class="flex justify-between"><span class="text-slate-500">Discount</span><span>{{ formatCurrency(invoice.discount) }}</span></div>
                        <div class="flex justify-between"><span class="text-slate-500">Additional Cost</span><span>{{ formatCurrency(invoice.additional_cost) }}</span></div>
                        <div class="flex justify-between text-base font-semibold border-t border-slate-200 pt-2">
                            <span>Grand Total</span><span>{{ formatCurrency(invoice.grand_total) }}</span>
                        </div>
                        <div class="flex justify-between"><span class="text-slate-500">Paid</span><span>{{ formatCurrency(invoice.paid_amount) }}</span></div>
                        <div class="flex justify-between font-medium">
                            <span :class="invoice.due_amount > 0 ? 'text-rose-600' : ''">Due</span>
                            <span :class="invoice.due_amount > 0 ? 'text-rose-600' : ''">{{ formatCurrency(invoice.due_amount) }}</span>
                        </div>
                    </div>
                </div>

                <p class="text-center text-xs text-slate-400 mt-10">Thank you for your business.</p>
            </div>

            <div class="no-print flex justify-center gap-3 mt-4">
                <button type="button" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover" @click="print">Print</button>
                <RouterLink :to="{ name: 'invoices.index' }" class="px-4 py-2 text-sm rounded-md border border-slate-300">Back</RouterLink>
            </div>
        </template>
    </AppLayout>
</template>
