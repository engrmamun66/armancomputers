<script setup>
import { computed } from 'vue';
import { Bar } from 'vue-chartjs';
import '@/utils/chartSetup';
import { formatDate } from '@/utils/format';

const props = defineProps({ points: { type: Array, default: () => [] } });

const chartData = computed(() => ({
    labels: props.points.map((p) => formatDate(p.date)),
    datasets: [
        { label: 'Purchase', data: props.points.map((p) => p.purchase_qty), backgroundColor: '#3b82f6' },
        { label: 'Sales', data: props.points.map((p) => p.sale_qty), backgroundColor: '#f97316' },
    ],
}));

const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { position: 'bottom' } },
    scales: { y: { beginAtZero: true } },
};
</script>

<template>
    <div class="h-64">
        <Bar :data="chartData" :options="options" />
    </div>
</template>
