<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { RouterLink, useRouter } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import ProductSearch from '@/components/common/ProductSearch.vue';
import CustomerSearch from '@/components/common/CustomerSearch.vue';
import EmDateTimePicker from '@/components/common/EmDateTimePicker.vue';
import Modal from '@/components/common/Modal.vue';
import SelectSearch from '@/components/common/SelectSearch.vue';
import salesApi from '@/services/sales';
import customersApi from '@/services/customers';
import lookups from '@/services/lookups';
import { useToast } from '@/composables/useToast';
import { formatCurrency, formatWarranty } from '@/utils/format';

const props = defineProps({ id: { type: [String, Number], default: null } });
const router = useRouter();
const toast = useToast();

const isEdit = computed(() => !!props.id);
const loading = ref(true);
const saving = ref(false);
const errors = ref({});
const generalError = ref('');
const referenceNo = ref(null);

const PAYMENT_METHODS = [
    { value: 'cash', label: 'Cash' },
    { value: 'bank', label: 'Bank' },
    { value: 'card', label: 'Card' },
    { value: 'mobile_banking', label: 'Mobile Banking' },
    { value: 'other', label: 'Other' },
];

const form = reactive({
    customer_id: null,
    sale_date: new Date().toISOString().slice(0, 10),
    warranty_end_date: '',
    notes: '',
    discount: 0,
    additional_cost: 0,
    paid_amount: 0,
    payment_method: 'cash',
});

const selectedCustomer = ref(null);
const items = ref([]);

onMounted(async () => {
    if (isEdit.value) {
        const { data } = await salesApi.get(props.id);
        const sale = data.data;
        referenceNo.value = sale.reference_no;
        selectedCustomer.value = sale.customer;
        Object.assign(form, {
            customer_id: sale.customer?.id,
            sale_date: sale.sale_date?.slice(0, 10),
            warranty_end_date: sale.warranty_end_date?.slice(0, 10) || '',
            notes: sale.notes || '',
            discount: sale.discount,
            additional_cost: sale.additional_cost,
            paid_amount: sale.paid_amount,
            payment_method: sale.payment_method,
        });
        items.value = sale.items.map((item) => ({
            product_id: item.product_id,
            name: item.product_name,
            sku: item.sku,
            available_stock: null,
            quantity: item.quantity,
            unit_price: item.unit_price,
        }));
    }
    loading.value = false;
});

function selectCustomer(customer) {
    selectedCustomer.value = customer;
    form.customer_id = customer.id;
}

// --- inline "create new customer" ---
const showCustomerModal = ref(false);
const customerForm = reactive({ name: '', phone: '', email: '', address: '' });
const customerErrors = ref({});
const savingCustomer = ref(false);

async function openCustomerModal(prefillName) {
    let statusId = null;
    try {
        const { data } = await lookups.statuses('general');
        statusId = data.data.find((s) => s.slug === 'active')?.id;
    } catch {
        // fall through with null status id if lookup fails; backend will reject if required
    }
    Object.assign(customerForm, { name: prefillName || '', phone: '', email: '', address: '', status_id: statusId });
    customerErrors.value = {};
    showCustomerModal.value = true;
}

async function submitCustomerModal() {
    savingCustomer.value = true;
    customerErrors.value = {};
    try {
        const { data } = await customersApi.create(customerForm);
        selectCustomer(data.data);
        showCustomerModal.value = false;
        toast.success('Customer created successfully.');
    } catch (error) {
        if (error.response?.status === 422) {
            customerErrors.value = error.response.data.errors || {};
        } else {
            toast.error(error.response?.data?.message || 'Something went wrong.');
        }
    } finally {
        savingCustomer.value = false;
    }
}

// --- product rows ---
function addProduct(product) {
    if (items.value.some((item) => item.product_id === product.id)) {
        toast.info('This product is already in the list.');
        return;
    }
    items.value.push({
        product_id: product.id,
        name: product.name,
        sku: product.sku,
        available_stock: product.current_stock,
        quantity: 1,
        unit_price: product.selling_price,
    });
}

function removeItem(index) {
    items.value.splice(index, 1);
}

const excludeIds = computed(() => items.value.map((item) => item.product_id));

function itemError(item) {
    if (item.available_stock !== null && Number(item.quantity) > item.available_stock) {
        return `Insufficient stock. Available quantity: ${item.available_stock}`;
    }
    return null;
}

const hasStockErrors = computed(() => items.value.some((item) => itemError(item)));

const subtotal = computed(() => items.value.reduce((sum, item) => sum + (Number(item.quantity) || 0) * (Number(item.unit_price) || 0), 0));
const grandTotal = computed(() => subtotal.value - (Number(form.discount) || 0) + (Number(form.additional_cost) || 0));
const dueAmount = computed(() => Math.max(0, grandTotal.value - (Number(form.paid_amount) || 0)));

async function submit() {
    generalError.value = '';
    errors.value = {};

    if (!form.customer_id) {
        generalError.value = 'Please select a customer.';
        return;
    }
    if (!items.value.length) {
        generalError.value = 'Add at least one product before saving.';
        return;
    }
    for (const item of items.value) {
        if (!item.quantity || item.quantity <= 0) {
            generalError.value = `Quantity for "${item.name}" must be greater than zero.`;
            return;
        }
        if (item.unit_price === '' || item.unit_price < 0) {
            generalError.value = `Unit price for "${item.name}" must be zero or more.`;
            return;
        }
    }
    if (hasStockErrors.value) {
        generalError.value = 'Fix the insufficient stock items before saving.';
        return;
    }

    saving.value = true;
    try {
        const payload = {
            customer_id: form.customer_id,
            sale_date: form.sale_date,
            warranty_end_date: form.warranty_end_date || null,
            notes: form.notes,
            discount: Number(form.discount) || 0,
            additional_cost: Number(form.additional_cost) || 0,
            paid_amount: Number(form.paid_amount) || 0,
            payment_method: form.payment_method,
            items: items.value.map((item) => ({
                product_id: item.product_id,
                quantity: Number(item.quantity),
                unit_price: Number(item.unit_price),
            })),
        };

        if (isEdit.value) {
            await salesApi.update(props.id, payload);
            toast.success('Sale updated successfully.');
        } else {
            await salesApi.create(payload);
            toast.success('Sale created successfully.');
        }
        router.push({ name: 'sales.index' });
    } catch (error) {
        if (error.response?.status === 422) {
            errors.value = error.response.data.errors || {};
            generalError.value = error.response.data.message || '';
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
            <h1 class="text-lg font-semibold text-slate-900">{{ isEdit ? 'Edit Sale' : 'New Sale' }}</h1>
            <RouterLink
                v-if="isEdit"
                :to="{ name: 'sales.show', params: { id: props.id } }"
                class="px-3 py-2 text-sm rounded-md border border-slate-300 hover:bg-slate-50"
            >
                View Details
            </RouterLink>
        </div>

        <LoadingSpinner v-if="loading" />
        <form v-else class="space-y-6" @submit.prevent="submit">
            <div v-if="generalError" class="rounded-md bg-rose-50 border border-rose-200 text-rose-700 text-sm px-4 py-3">
                {{ generalError }}
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6">
                <h2 class="text-sm font-semibold text-slate-700 mb-4">Customer Information</h2>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div class="sm:col-span-2">
                        <label class="block text-sm font-medium text-slate-700 mb-1">Customer</label>
                        <div v-if="selectedCustomer" class="flex items-center justify-between px-3 py-2 border border-slate-300 rounded-md bg-slate-50">
                            <span class="text-sm font-medium text-slate-800">{{ selectedCustomer.name }} <span class="text-slate-400 font-normal">· {{ selectedCustomer.phone || 'no phone' }}</span></span>
                            <button type="button" class="text-sm text-link" @click="selectedCustomer = null; form.customer_id = null">Change</button>
                        </div>
                        <CustomerSearch v-else @select="selectCustomer" @create-new="openCustomerModal" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Reference No</label>
                        <input :value="referenceNo || 'Auto-generated on save'" type="text" disabled class="w-full px-3 py-2 text-sm border border-slate-200 bg-slate-50 text-slate-400 rounded-md" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Sale Date</label>
                        <EmDateTimePicker
                            v-model="form.sale_date"
                            model-value-type="date"
                            classes="w-full px-3 py-2 text-sm border border-slate-300 rounded-md"
                        />
                        <p v-if="errors.sale_date" class="mt-1 text-xs text-rose-600">{{ errors.sale_date[0] }}</p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Warranty End Date</label>
                        <EmDateTimePicker
                            v-model="form.warranty_end_date"
                            model-value-type="date"
                            placeholder="Optional"
                            classes="w-full px-3 py-2 text-sm border border-slate-300 rounded-md"
                        />
                        <p v-if="errors.warranty_end_date" class="mt-1 text-xs text-rose-600">{{ errors.warranty_end_date[0] }}</p>
                    </div>
                </div>
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6">
                <h2 class="text-sm font-semibold text-slate-700 mb-4">Products</h2>
                <ProductSearch :exclude-ids="excludeIds" placeholder="Search product to sell…" @select="addProduct" />

                <div class="mt-4 overflow-x-auto">
                    <table class="min-w-full text-sm">
                        <thead>
                            <tr class="text-left text-slate-500 border-b border-slate-200">
                                <th class="py-2 pr-3">Product</th>
                                <th class="py-2 pr-3">SKU</th>
                                <th class="py-2 pr-3 text-center">Available Stock</th>
                                <th class="py-2 pr-3 text-center w-28">Qty</th>
                                <th class="py-2 pr-3 text-right w-32">Unit Price</th>
                                <th class="py-2 pr-3 text-right">Total</th>
                                <th class="py-2 pr-3">Warranty</th>
                                <th class="py-2"></th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-if="!items.length">
                                <td colspan="8" class="py-6 text-center text-slate-400">No products added yet. Search above to add one.</td>
                            </tr>
                            <template v-for="(item, index) in items" :key="item.product_id">
                                <tr class="border-b border-slate-100">
                                    <td class="py-2 pr-3 font-medium text-slate-800">{{ item.name }}</td>
                                    <td class="py-2 pr-3 text-slate-500">{{ item.sku }}</td>
                                    <td class="py-2 pr-3 text-center" :class="item.available_stock <= 0 ? 'text-rose-600 font-medium' : 'text-slate-500'">
                                        {{ item.available_stock ?? '—' }}
                                    </td>
                                    <td class="py-2 pr-3">
                                        <input v-model.number="item.quantity" type="number" min="1" class="w-full px-2 py-1 text-center border rounded-md" :class="itemError(item) ? 'border-rose-400' : 'border-slate-300'" />
                                    </td>
                                    <td class="py-2 pr-3">
                                        <input v-model.number="item.unit_price" type="number" min="0" step="0.01" class="w-full px-2 py-1 text-right border border-slate-300 rounded-md" />
                                    </td>
                                    <td class="py-2 pr-3 text-right font-medium">{{ formatCurrency((item.quantity || 0) * (item.unit_price || 0)) }}</td>
                                    <td class="py-2 pr-3 text-slate-500">{{ formatWarranty(form.sale_date, form.warranty_end_date) || '—' }}</td>
                                    <td class="py-2 text-right">
                                        <button type="button" class="text-rose-600 hover:text-rose-700" @click="removeItem(index)">Remove</button>
                                    </td>
                                </tr>
                                <tr v-if="itemError(item)">
                                    <td colspan="8" class="pb-2 text-xs text-rose-600">{{ itemError(item) }}</td>
                                </tr>
                            </template>
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6 max-w-md ml-auto space-y-3">
                <div class="flex justify-between text-sm">
                    <span class="text-slate-500">Subtotal</span>
                    <span class="font-medium">{{ formatCurrency(subtotal) }}</span>
                </div>
                <div class="flex justify-between items-center text-sm">
                    <span class="text-slate-500">Discount</span>
                    <input v-model.number="form.discount" type="number" min="0" step="0.01" class="w-32 px-2 py-1 text-right border border-slate-300 rounded-md" />
                </div>
                <div class="flex justify-between items-center text-sm">
                    <span class="text-slate-500">Additional Cost</span>
                    <input v-model.number="form.additional_cost" type="number" min="0" step="0.01" class="w-32 px-2 py-1 text-right border border-slate-300 rounded-md" />
                </div>
                <div class="flex justify-between text-base font-semibold border-t border-slate-200 pt-3">
                    <span>Grand Total</span>
                    <span>{{ formatCurrency(grandTotal) }}</span>
                </div>
                <div class="flex justify-between items-center text-sm border-t border-slate-200 pt-3">
                    <span class="text-slate-500">Payment Method</span>
                    <div class="w-40">
                        <SelectSearch v-model="form.payment_method" :options="PAYMENT_METHODS" placeholder="Select method" />
                    </div>
                </div>
                <div class="flex justify-between items-center text-sm">
                    <span class="text-slate-500">Paid Amount</span>
                    <input v-model.number="form.paid_amount" type="number" min="0" step="0.01" class="w-32 px-2 py-1 text-right border border-slate-300 rounded-md" />
                </div>
                <div class="flex justify-between text-sm font-medium">
                    <span :class="dueAmount > 0 ? 'text-rose-600' : 'text-slate-500'">Due Amount</span>
                    <span :class="dueAmount > 0 ? 'text-rose-600' : ''">{{ formatCurrency(dueAmount) }}</span>
                </div>
            </div>

            <div class="flex justify-end gap-3">
                <RouterLink :to="{ name: 'sales.index' }" class="px-4 py-2 text-sm rounded-md bg-[#f24c17] text-white hover:bg-[#d8430f]">Cancel</RouterLink>
                <button type="submit" :disabled="saving" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover disabled:opacity-60">
                    {{ saving ? 'Saving…' : 'Save Sale' }}
                </button>
            </div>
        </form>

        <Modal v-model="showCustomerModal" title="Add New Customer" size="sm">
            <form class="space-y-4" @submit.prevent="submitCustomerModal">
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Customer Name</label>
                    <input v-model="customerForm.name" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="customerErrors.name" class="mt-1 text-xs text-rose-600">{{ customerErrors.name[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Phone</label>
                    <input v-model="customerForm.phone" type="text" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Email</label>
                    <input v-model="customerForm.email" type="email" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="customerErrors.email" class="mt-1 text-xs text-rose-600">{{ customerErrors.email[0] }}</p>
                </div>
            </form>
            <template #footer>
                <button type="button" class="px-4 py-2 text-sm rounded-md bg-[#f24c17] text-white hover:bg-[#d8430f]" @click="showCustomerModal = false">Cancel</button>
                <button type="button" :disabled="savingCustomer" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover disabled:opacity-60" @click="submitCustomerModal">
                    {{ savingCustomer ? 'Saving…' : 'Save Customer' }}
                </button>
            </template>
        </Modal>
    </AppLayout>
</template>
