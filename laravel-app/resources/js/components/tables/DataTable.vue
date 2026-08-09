<script setup>
import Icon from '@/components/common/Icon.vue';

const props = defineProps({
    columns: {
        type: Array,
        required: true,
        // [{ key, label, align: 'left'|'right'|'center', class, sortable: false }]
    },
    rows: { type: Array, required: true },
    rowKey: { type: String, default: 'id' },
    loading: { type: Boolean, default: false },
    sortBy: { type: String, default: null },
    sortDir: { type: String, default: 'asc' },
});

const emit = defineEmits(['sort']);

const NOT_SORTABLE = ['index', 'actions'];

function isSortable(column) {
    return column.sortable !== false && !NOT_SORTABLE.includes(column.key);
}

function sortIcon(column) {
    if (props.sortBy !== column.key) return 'sort';
    return props.sortDir === 'asc' ? 'chevron-up' : 'chevron-down';
}
</script>

<template>
    <div class="hidden md:block overflow-x-auto border border-slate-200 rounded-lg bg-white">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
            <thead class="bg-slate-50">
                <tr>
                    <th
                        v-for="column in columns"
                        :key="column.key"
                        :class="[
                            'px-4 py-3 font-medium text-slate-500 whitespace-nowrap',
                            column.align === 'right' ? 'text-right' : column.align === 'center' ? 'text-center' : 'text-left',
                            column.class,
                        ]"
                    >
                        <button
                            v-if="isSortable(column)"
                            type="button"
                            class="inline-flex items-center gap-1 group hover:text-slate-700"
                            :class="column.align === 'right' ? 'flex-row-reverse' : ''"
                            @click="emit('sort', column.key)"
                        >
                            {{ column.label }}
                            <Icon
                                :name="sortIcon(column)"
                                class="h-3.5 w-3.5 shrink-0"
                                :class="sortBy === column.key ? 'text-slate-700' : 'text-slate-400 group-hover:text-slate-500'"
                            />
                        </button>
                        <span v-else>{{ column.label }}</span>
                    </th>
                </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
                <tr v-if="loading">
                    <td :colspan="columns.length" class="px-4 py-8 text-center text-slate-400">Loading…</td>
                </tr>
                <tr v-else-if="!rows.length">
                    <td :colspan="columns.length" class="px-4 py-8 text-center text-slate-400">No records found.</td>
                </tr>
                <tr v-for="(row, index) in rows" v-else :key="row[rowKey] ?? index" class="hover:bg-slate-50">
                    <td
                        v-for="column in columns"
                        :key="column.key"
                        :class="[
                            'px-4 py-3 whitespace-nowrap text-slate-700',
                            column.align === 'right' ? 'text-right' : column.align === 'center' ? 'text-center' : 'text-left',
                        ]"
                    >
                        <slot :name="`cell-${column.key}`" :row="row" :index="index">
                            {{ row[column.key] }}
                        </slot>
                    </td>
                </tr>
            </tbody>
            <tfoot v-if="$slots.footer">
                <slot name="footer" />
            </tfoot>
        </table>
    </div>
</template>
