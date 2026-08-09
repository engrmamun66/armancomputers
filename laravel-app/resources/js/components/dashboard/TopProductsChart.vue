<script setup>
import { computed } from 'vue';
import { Bar } from 'vue-chartjs';
import '@/utils/chartSetup';

const props = defineProps({ products: { type: Array, default: () => [] } });

const chartData = computed(() => ({
    labels: props.products.map((p) => p.name),
    datasets: [{ label: 'Qty Sold', data: props.products.map((p) => p.qty_sold), backgroundColor: '#10b981' }],
}));

const options = {
    indexAxis: 'y',
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { display: false } },
    scales: { x: { beginAtZero: true } },
};
</script>

<template>
    <div class="h-64">
        <Bar :data="chartData" :options="options" />
    </div>
</template>
