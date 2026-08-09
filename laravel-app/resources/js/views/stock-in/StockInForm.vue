<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { RouterLink, useRouter } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import ProductSearch from '@/components/common/ProductSearch.vue';
import stockInsApi from '@/services/stockIns';
import { useToast } from '@/composables/useToast';
import { formatCurrency } from '@/utils/format';

const props = defineProps({ id: { type: [String, Number], default: null } });
const router = useRouter();
const toast = useToast();

const isEdit = computed(() => !!props.id);
const loading = ref(true);
const saving = ref(false);
const errors = ref({});
const generalError = ref('');
const referenceNo = ref(null);

const form = reactive({
    supplier_name: '',
    supplier_phone: '',
    purchase_date: new Date().toISOString().slice(0, 10),
    notes: '',
    discount: 0,
    additional_cost: 0,
});

const items = ref([]);

onMounted(async () => {
    if (isEdit.value) {
        const { data } = await stockInsApi.get(props.id);
        const stockIn = data.data;
        referenceNo.value = stockIn.reference_no;
        Object.assign(form, {
            supplier_name: stockIn.supplier_name || '',
            supplier_phone: stockIn.supplier_phone || '',
            purchase_date: stockIn.purchase_date?.slice(0, 10),
            notes: stockIn.notes || '',
            discount: stockIn.discount,
            additional_cost: stockIn.additional_cost,
        });
        items.value = stockIn.items.map((item) => ({
            product_id: item.product_id,
            name: item.product_name,
            sku: item.sku,
            current_stock: null,
            quantity: item.quantity,
            unit_price: item.unit_price,
        }));
    }
    loading.value = false;
});

function addProduct(product) {
    if (items.value.some((item) => item.product_id === product.id)) {
        toast.info('This product is already in the list.');
        return;
    }
    items.value.push({
        product_id: product.id,
        name: product.name,
        sku: product.sku,
        current_stock: product.current_stock,
        quantity: 1,
        unit_price: product.purchase_price,
    });
}

function removeItem(index) {
    items.value.splice(index, 1);
}

const excludeIds = computed(() => items.value.map((item) => item.product_id));

const subtotal = computed(() => items.value.reduce((sum, item) => sum + (Number(item.quantity) || 0) * (Number(item.unit_price) || 0), 0));
const grandTotal = computed(() => subtotal.value - (Number(form.discount) || 0) + (Number(form.additional_cost) || 0));

async function submit() {
    generalError.value = '';
    errors.value = {};

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

    saving.value = true;
    try {
        const payload = {
            ...form,
            items: items.value.map((item) => ({
                product_id: item.product_id,
                quantity: Number(item.quantity),
                unit_price: Number(item.unit_price),
            })),
        };

        if (isEdit.value) {
            await stockInsApi.update(props.id, payload);
            toast.success('Stock In updated successfully.');
        } else {
            await stockInsApi.create(payload);
            toast.success('Stock In created successfully.');
        }
        router.push({ name: 'stock-in.index' });
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
        <h1 class="text-lg font-semibold text-slate-900 mb-4">{{ isEdit ? 'Edit Stock In' : 'New Stock In' }}</h1>

        <LoadingSpinner v-if="loading" />
        <form v-else class="space-y-6" @submit.prevent="submit">
            <div v-if="generalError" class="rounded-md bg-rose-50 border border-rose-200 text-rose-700 text-sm px-4 py-3">
                {{ generalError }}
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6">
                <h2 class="text-sm font-semibold text-slate-700 mb-4">Basic Information</h2>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Reference No</label>
                        <input
                            :value="referenceNo || 'Auto-generated on save'"
                            type="text"
                            disabled
                            class="w-full px-3 py-2 text-sm border border-slate-200 bg-slate-50 text-slate-400 rounded-md"
                        />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Purchase Date</label>
                        <input v-model="form.purchase_date" type="date" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                        <p v-if="errors.purchase_date" class="mt-1 text-xs text-rose-600">{{ errors.purchase_date[0] }}</p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Supplier Name</label>
                        <input v-model="form.supplier_name" type="text" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Supplier Phone</label>
                        <input v-model="form.supplier_phone" type="text" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    </div>
                    <div class="sm:col-span-2">
                        <label class="block text-sm font-medium text-slate-700 mb-1">Notes</label>
                        <textarea v-model="form.notes" rows="2" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md"></textarea>
                    </div>
                </div>
            </div>

            <div class="bg-white border border-slate-200 rounded-lg p-6">
                <h2 class="text-sm font-semibold text-slate-700 mb-4">Products</h2>
                <ProductSearch :exclude-ids="excludeIds" placeholder="Search product to add…" @select="addProduct" />

                <div class="mt-4 overflow-x-auto">
                    <table class="min-w-full text-sm">
                        <thead>
                            <tr class="text-left text-slate-500 border-b border-slate-200">
                                <th class="py-2 pr-3">Product</th>
                                <th class="py-2 pr-3">SKU</th>
                                <th class="py-2 pr-3 text-right">Current Stock</th>
                                <th class="py-2 pr-3 text-right w-28">Qty</th>
                                <th class="py-2 pr-3 text-right w-32">Unit Price</th>
                                <th class="py-2 pr-3 text-right">Total</th>
                                <th class="py-2"></th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-if="!items.length">
                                <td colspan="7" class="py-6 text-center text-slate-400">No products added yet. Search above to add one.</td>
                            </tr>
                            <tr v-for="(item, index) in items" :key="item.product_id" class="border-b border-slate-100">
                                <td class="py-2 pr-3 font-medium text-slate-800">{{ item.name }}</td>
                                <td class="py-2 pr-3 text-slate-500">{{ item.sku }}</td>
                                <td class="py-2 pr-3 text-right text-slate-500">{{ item.current_stock ?? '—' }}</td>
                                <td class="py-2 pr-3">
                                    <input v-model.number="item.quantity" type="number" min="1" class="w-full px-2 py-1 text-right border border-slate-300 rounded-md" />
                                </td>
                                <td class="py-2 pr-3">
                                    <input v-model.number="item.unit_price" type="number" min="0" step="0.01" class="w-full px-2 py-1 text-right border border-slate-300 rounded-md" />
                                </td>
                                <td class="py-2 pr-3 text-right font-medium">{{ formatCurrency((item.quantity || 0) * (item.unit_price || 0)) }}</td>
                                <td class="py-2 text-right">
                                    <button type="button" class="text-rose-600 hover:text-rose-700" @click="removeItem(index)">Remove</button>
                                </td>
                            </tr>
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
            </div>

            <div class="flex justify-end gap-3">
                <RouterLink :to="{ name: 'stock-in.index' }" class="px-4 py-2 text-sm rounded-md border border-slate-300">Cancel</RouterLink>
                <button type="submit" :disabled="saving" class="px-4 py-2 text-sm rounded-md bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-60">
                    {{ saving ? 'Saving…' : 'Save Stock In' }}
                </button>
            </div>
        </form>
    </AppLayout>
</template>
