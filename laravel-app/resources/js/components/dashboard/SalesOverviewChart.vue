<script setup>
import { computed } from 'vue';
import { Line } from 'vue-chartjs';
import '@/utils/chartSetup';
import { formatDate } from '@/utils/format';

const props = defineProps({ points: { type: Array, default: () => [] } });

const chartData = computed(() => ({
    labels: props.points.map((p) => formatDate(p.date)),
    datasets: [
        {
            label: 'Sales',
            data: props.points.map((p) => p.total),
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59,130,246,0.1)',
            fill: true,
            tension: 0.3,
        },
    ],
}));

const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { display: false } },
    scales: { y: { beginAtZero: true } },
};
</script>

<template>
    <div class="h-64">
        <Line :data="chartData" :options="options" />
    </div>
</template>
