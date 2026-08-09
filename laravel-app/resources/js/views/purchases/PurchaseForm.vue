<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { RouterLink, useRouter } from 'vue-router';
import AppLayout from '@/layouts/AppLayout.vue';
import LoadingSpinner from '@/components/common/LoadingSpinner.vue';
import ProductSearch from '@/components/common/ProductSearch.vue';
import EmDateTimePicker from '@/components/common/EmDateTimePicker.vue';
import Modal from '@/components/common/Modal.vue';
import SelectSearch from '@/components/common/SelectSearch.vue';
import purchasesApi from '@/services/purchases';
import productsApi from '@/services/products';
import brandsApi from '@/services/brands';
import lookups from '@/services/lookups';
import { useToast } from '@/composables/useToast';
import Icon from '@/components/common/Icon.vue';
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
    warranty_end_date: '',
    notes: '',
    discount: 0,
    additional_cost: 0,
});

const items = ref([]);

const brands = ref([]);
const productStatuses = ref([]);

onMounted(async () => {
    const [brandRes, statusRes] = await Promise.all([brandsApi.all(), lookups.statuses('general')]);
    brands.value = brandRes.data.data;
    productStatuses.value = statusRes.data.data;

    if (isEdit.value) {
        const { data } = await purchasesApi.get(props.id);
        const purchase = data.data;
        referenceNo.value = purchase.reference_no;
        Object.assign(form, {
            supplier_name: purchase.supplier_name || '',
            supplier_phone: purchase.supplier_phone || '',
            purchase_date: purchase.purchase_date?.slice(0, 10),
            warranty_end_date: purchase.warranty_end_date?.slice(0, 10) || '',
            notes: purchase.notes || '',
            discount: purchase.discount,
            additional_cost: purchase.additional_cost,
        });
        items.value = purchase.items.map((item) => ({
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

const savingPriceFor = ref(null);

async function savePurchasePrice(item) {
    if (item.unit_price === '' || item.unit_price < 0) {
        toast.error('Enter a valid price before saving.');
        return;
    }
    savingPriceFor.value = item.product_id;
    try {
        await productsApi.update(item.product_id, { purchase_price: Number(item.unit_price) });
        toast.success(`Updated ${item.name}'s purchase price.`);
    } catch (error) {
        toast.error(error.response?.data?.message || 'Failed to update purchase price.');
    } finally {
        savingPriceFor.value = null;
    }
}

const excludeIds = computed(() => items.value.map((item) => item.product_id));

// --- inline "create new product" ---
const brandOptions = computed(() => brands.value.map((brand) => ({ value: brand.id, label: brand.name })));
const statusOptions = computed(() => productStatuses.value.map((status) => ({ value: status.id, label: status.name })));

const showProductModal = ref(false);
const productForm = reactive({
    brand_id: '',
    name: '',
    barcode: '',
    description: '',
    purchase_price: '',
    selling_price: '',
    minimum_stock: 5,
    status_id: '',
});
const productErrors = ref({});
const savingProduct = ref(false);

function openProductModal(prefillName) {
    Object.assign(productForm, {
        brand_id: '',
        name: prefillName || '',
        barcode: '',
        description: '',
        purchase_price: '',
        selling_price: '',
        minimum_stock: 5,
        status_id: productStatuses.value.find((s) => s.slug === 'active')?.id ?? '',
    });
    productErrors.value = {};
    showProductModal.value = true;
}

async function createBrand(name) {
    const activeStatusId = productStatuses.value.find((s) => s.slug === 'active')?.id;
    const { data } = await brandsApi.create({ name, status_id: activeStatusId });
    brands.value.push(data.data);
    toast.success(`Brand "${data.data.name}" added.`);
    return { value: data.data.id, label: data.data.name };
}

async function submitProductModal() {
    savingProduct.value = true;
    productErrors.value = {};
    try {
        const { data } = await productsApi.create(productForm);
        addProduct(data.data);
        showProductModal.value = false;
        toast.success('Product created successfully.');
    } catch (error) {
        if (error.response?.status === 422) {
            productErrors.value = error.response.data.errors || {};
        } else {
            toast.error(error.response?.data?.message || 'Something went wrong.');
        }
    } finally {
        savingProduct.value = false;
    }
}

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
            warranty_end_date: form.warranty_end_date || null,
            items: items.value.map((item) => ({
                product_id: item.product_id,
                quantity: Number(item.quantity),
                unit_price: Number(item.unit_price),
            })),
        };

        if (isEdit.value) {
            await purchasesApi.update(props.id, payload);
            toast.success('Purchase updated successfully.');
        } else {
            await purchasesApi.create(payload);
            toast.success('Purchase created successfully.');
        }
        router.push({ name: 'purchases.index' });
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
            <h1 class="text-lg font-semibold text-slate-900">{{ isEdit ? 'Edit Purchase' : 'New Purchase' }}</h1>
            <RouterLink :to="{ name: 'purchases.index' }" class="px-3 py-2 text-sm rounded-md border border-slate-300 hover:bg-slate-50">
                Back
            </RouterLink>
        </div>

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
                        <EmDateTimePicker
                            v-model="form.purchase_date"
                            model-value-type="date"
                            classes="w-full px-3 py-2 text-sm border border-slate-300 rounded-md"
                        />
                        <p v-if="errors.purchase_date" class="mt-1 text-xs text-rose-600">{{ errors.purchase_date[0] }}</p>
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
                <div class="flex items-center justify-between mb-4">
                    <h2 class="text-sm font-semibold text-slate-700">Products</h2>
                    <button
                        type="button"
                        class="px-3 py-1.5 text-xs font-medium rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover"
                        @click="openProductModal()"
                    >
                        + Add new product
                    </button>
                </div>
                <ProductSearch :exclude-ids="excludeIds" placeholder="Search product to add…" allow-create @select="addProduct" @create-new="openProductModal" />

                <div class="mt-4 overflow-x-auto">
                    <table class="min-w-full text-sm">
                        <thead>
                            <tr class="text-left text-slate-500 border-b border-slate-200">
                                <th class="py-2 pr-3">Product</th>
                                <th class="py-2 pr-3 text-center">Current Stock</th>
                                <th class="py-2 pr-3 text-center w-28">Qty</th>
                                <th class="py-2 pr-3 text-left w-32">Unit Price</th>
                                <th class="py-2 pr-3 text-right">Total</th>
                                <th class="py-2"></th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-if="!items.length">
                                <td colspan="6" class="py-6 text-center text-slate-400">No products added yet. Search above to add one.</td>
                            </tr>
                            <tr v-for="(item, index) in items" :key="item.product_id" class="border-b border-slate-100">
                                <td class="py-2 pr-3 font-medium text-slate-800">{{ item.name }}</td>
                                <td class="py-2 pr-3 text-center text-slate-500">{{ item.current_stock ?? '—' }}</td>
                                <td class="py-2 pr-3">
                                    <input v-model.number="item.quantity" type="number" min="1" class="w-full px-2 py-1 text-center border border-slate-300 rounded-md" />
                                </td>
                                <td class="py-2 pr-3">
                                    <div class="flex items-center gap-1">
                                        <input v-model.number="item.unit_price" type="number" min="0" step="0.01" class="w-full min-w-[120px] px-2 py-1 text-left border border-slate-300 rounded-md" />
                                        <button
                                            type="button"
                                            title="Save as this product's purchase price"
                                            :disabled="savingPriceFor === item.product_id"
                                            class="shrink-0 h-7 w-7 flex items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-700 disabled:opacity-50"
                                            @click="savePurchasePrice(item)"
                                        >
                                            <Icon v-if="savingPriceFor !== item.product_id" name="check" class="h-4 w-4" />
                                            <svg v-else class="h-4 w-4 animate-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" d="M12 3a9 9 0 100 18" /></svg>
                                        </button>
                                    </div>
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
                <RouterLink :to="{ name: 'purchases.index' }" class="px-4 py-2 text-sm rounded-md bg-[#f24c17] text-white hover:bg-[#d8430f]">Cancel</RouterLink>
                <button type="submit" :disabled="saving" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover disabled:opacity-60">
                    {{ saving ? 'Saving…' : 'Save Purchase' }}
                </button>
            </div>
        </form>

        <Modal v-model="showProductModal" title="Add New Product" size="lg">
            <form class="space-y-4" @submit.prevent="submitProductModal">
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Brand</label>
                        <SelectSearch
                            v-model="productForm.brand_id"
                            :options="brandOptions"
                            placeholder="Select a brand"
                            allow-create
                            :create-fn="createBrand"
                            create-label="Add brand"
                        />
                        <p v-if="productErrors.brand_id" class="mt-1 text-xs text-rose-600">{{ productErrors.brand_id[0] }}</p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Status</label>
                        <SelectSearch v-model="productForm.status_id" :options="statusOptions" placeholder="Select a status" />
                    </div>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Product Name</label>
                    <input v-model="productForm.name" type="text" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="productErrors.name" class="mt-1 text-xs text-rose-600">{{ productErrors.name[0] }}</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Barcode <span class="text-slate-400 font-normal">(optional)</span></label>
                    <input v-model="productForm.barcode" type="text" class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                    <p v-if="productErrors.barcode" class="mt-1 text-xs text-rose-600">{{ productErrors.barcode[0] }}</p>
                </div>
                <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Purchase Price</label>
                        <input v-model="productForm.purchase_price" type="number" step="0.01" min="0" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                        <p v-if="productErrors.purchase_price" class="mt-1 text-xs text-rose-600">{{ productErrors.purchase_price[0] }}</p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Selling Price</label>
                        <input v-model="productForm.selling_price" type="number" step="0.01" min="0" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                        <p v-if="productErrors.selling_price" class="mt-1 text-xs text-rose-600">{{ productErrors.selling_price[0] }}</p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">Minimum Stock</label>
                        <input v-model="productForm.minimum_stock" type="number" min="0" required class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md" />
                        <p v-if="productErrors.minimum_stock" class="mt-1 text-xs text-rose-600">{{ productErrors.minimum_stock[0] }}</p>
                    </div>
                </div>
            </form>
            <template #footer>
                <button type="button" class="px-4 py-2 text-sm rounded-md bg-[#f24c17] text-white hover:bg-[#d8430f]" @click="showProductModal = false">Cancel</button>
                <button type="button" :disabled="savingProduct" class="px-4 py-2 text-sm rounded-md bg-accent-solid text-on-accent-solid hover:bg-accent-solid-hover disabled:opacity-60" @click="submitProductModal">
                    {{ savingProduct ? 'Saving…' : 'Save Product' }}
                </button>
            </template>
        </Modal>
    </AppLayout>
</template>
