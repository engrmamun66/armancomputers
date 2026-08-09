<script setup>
import { computed, ref } from 'vue';
import { useRoute, useRouter, RouterLink } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { can } from '@/utils/permissions';
import Icon from '@/components/common/Icon.vue';
import ThemeToggle from '@/components/common/ThemeToggle.vue';
import logoSquare from '@/../images/logo-square.png';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();

const role = computed(() => auth.roleSlug);

const NAV_ITEMS = [
    { name: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
    { name: 'products.index', label: 'Products', icon: 'box' },
    { name: 'brands.index', label: 'Brands', icon: 'tag', capability: 'brands.manage' },
    { name: 'customers.index', label: 'Customers', icon: 'user-group' },
    { name: 'purchases.index', label: 'Purchase', icon: 'arrow-down-tray', capability: 'purchases.manage' },
    { name: 'sales.index', label: 'Sales', icon: 'arrow-up-tray' },
    { name: 'invoices.index', label: 'Invoices', icon: 'document-text' },
    { name: 'users.index', label: 'Users', icon: 'user-group', capability: 'users' },
];

const BREADCRUMBS = {
    'dashboard': 'Dashboard',
    'products.index': 'Products', 'products.create': 'Add Product', 'products.edit': 'Edit Product',
    'products.show': 'Product Details', 'products.stock-history': 'Stock History',
    'brands.index': 'Brands',
    'customers.index': 'Customers', 'customers.show': 'Customer Details',
    'purchases.index': 'Purchase', 'purchases.create': 'New Purchase', 'purchases.edit': 'Edit Purchase', 'purchases.show': 'Purchase Details',
    'sales.index': 'Sales', 'sales.create': 'New Sale', 'sales.edit': 'Edit Sale', 'sales.show': 'Sale Details',
    'invoices.index': 'Invoices', 'invoices.show': 'Invoice',
    'users.index': 'Users',
    'profile': 'Profile',
    'contact': 'Contact',
    'privacy': 'Privacy Policy',
};

const visibleNavItems = computed(() => NAV_ITEMS.filter((item) => !item.capability || can(role.value, item.capability)));

const mobilePrimaryNames = computed(() => {
    const second = can(role.value, 'purchases.manage') ? 'purchases.index' : 'invoices.index';
    return ['dashboard', second, 'products.index', 'sales.index'];
});

const mobilePrimaryItems = computed(() =>
    mobilePrimaryNames.value.map((name) => NAV_ITEMS.find((item) => item.name === name)).filter(Boolean)
);

const mobileMoreItems = computed(() => visibleNavItems.value.filter((item) => !mobilePrimaryNames.value.includes(item.name)));

const breadcrumb = computed(() => BREADCRUMBS[route.name] || '');

const userMenuOpen = ref(false);
const moreSheetOpen = ref(false);

async function handleLogout() {
    await auth.logout();
    router.push({ name: 'login' });
}
</script>

<template>
    <div class="min-h-screen bg-slate-50 flex flex-col">
        <header class="no-print bg-white border-b border-slate-200 sticky top-0 z-40">
            <div class="px-4 sm:px-6 h-16 flex items-center justify-between">
                <RouterLink :to="{ name: 'dashboard' }" class="flex items-center gap-2">
                    <img :src="logoSquare" alt="Arman Computers" class="h-10 w-10 object-contain" />
                    <span class="font-semibold text-slate-900 hidden sm:inline">Arman Computers</span>
                </RouterLink>

                <div class="flex items-center gap-2">
                <ThemeToggle />
                <div class="relative">
                    <button
                        type="button"
                        class="flex items-center gap-2 text-sm font-medium text-slate-700 hover:text-slate-900"
                        @click="userMenuOpen = !userMenuOpen"
                    >
                        <span class="h-8 w-8 rounded-full bg-slate-200 flex items-center justify-center text-slate-600 text-sm font-semibold overflow-hidden">
                            <img v-if="auth.user?.avatar" :src="auth.user.avatar" class="h-full w-full object-cover" alt="" />
                            <span v-else>{{ auth.user?.name?.charAt(0)?.toUpperCase() || '?' }}</span>
                        </span>
                        <span class="hidden sm:inline">{{ auth.user?.name }}</span>
                        <Icon name="chevron-down" class="h-4 w-4" />
                    </button>

                    <div
                        v-if="userMenuOpen"
                        class="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg border border-slate-200 py-1 text-sm"
                        @click="userMenuOpen = false"
                    >
                        <p class="px-4 py-2 text-xs text-slate-400 uppercase tracking-wide">{{ auth.user?.role?.name }}</p>
                        <RouterLink :to="{ name: 'profile' }" class="block px-4 py-2 text-slate-700 hover:bg-slate-50">Profile</RouterLink>
                        <RouterLink v-if="route.name !== 'contact'" :to="{ name: 'contact' }" class="block px-4 py-2 text-slate-700 hover:bg-slate-50">Contact</RouterLink>
                        <button type="button" class="w-full text-left px-4 py-2 text-rose-600 hover:bg-rose-50" @click="handleLogout">
                            Logout
                        </button>
                    </div>
                </div>
                </div>
            </div>
        </header>

        <div class="flex flex-1">
            <aside class="no-print hidden md:flex md:flex-col w-56 shrink-0 border-r border-slate-200 bg-white">
                <nav class="flex-1 px-3 py-4 space-y-1">
                    <RouterLink
                        v-for="item in visibleNavItems"
                        :key="item.name"
                        :to="{ name: item.name }"
                        class="flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium"
                        :class="route.name === item.name || route.name?.startsWith(item.name.split('.')[0] + '.')
                            ? 'bg-accent-solid text-on-accent-solid'
                            : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'"
                    >
                        <Icon :name="item.icon" class="h-5 w-5" />
                        {{ item.label }}
                    </RouterLink>
                </nav>
            </aside>

            <main class="flex-1 min-w-0 pb-20 md:pb-6">
                <div class="px-4 sm:px-6 py-4">
                    <nav v-if="breadcrumb" class="no-print text-sm text-slate-500 mb-4">
                        <RouterLink :to="{ name: 'dashboard' }" class="hover:text-slate-700">Home</RouterLink>
                        <span class="mx-1.5">/</span>
                        <span class="text-slate-700 font-medium">{{ breadcrumb }}</span>
                    </nav>
                    <slot />
                </div>
            </main>
        </div>

        <footer class="no-print hidden md:block border-t border-slate-200 bg-white">
            <div class="px-6 py-4 flex items-center justify-between text-sm text-slate-500">
                <p>&copy; {{ new Date().getFullYear() }} Arman Computers. All rights reserved.</p>
                <div class="flex gap-4">
                    <RouterLink v-if="route.name !== 'contact'" :to="{ name: 'contact' }" class="hover:text-slate-700">Contact</RouterLink>
                    <RouterLink v-if="route.name !== 'privacy'" :to="{ name: 'privacy' }" class="hover:text-slate-700">Privacy Policy</RouterLink>
                </div>
            </div>
        </footer>

        <nav class="no-print md:hidden fixed bottom-0 inset-x-0 z-40 bg-white border-t border-slate-200 flex">
            <RouterLink
                v-for="item in mobilePrimaryItems"
                :key="item.name"
                :to="{ name: item.name }"
                class="flex-1 flex flex-col items-center justify-center gap-0.5 py-2 text-xs"
                :class="route.name === item.name ? 'text-link' : 'text-slate-500'"
            >
                <Icon :name="item.icon" class="h-5 w-5" />
                {{ item.label }}
            </RouterLink>
            <button
                type="button"
                class="flex-1 flex flex-col items-center justify-center gap-0.5 py-2 text-xs"
                :class="moreSheetOpen ? 'text-link' : 'text-slate-500'"
                @click="moreSheetOpen = true"
            >
                <Icon name="ellipsis-horizontal" class="h-5 w-5" />
                More
            </button>
        </nav>

        <Teleport to="body">
            <div v-if="moreSheetOpen" class="md:hidden fixed inset-0 z-50 flex items-end">
                <div class="absolute inset-0 bg-overlay-solid/50" @click="moreSheetOpen = false" />
                <div class="relative bg-white rounded-t-2xl w-full p-4 pb-[calc(env(safe-area-inset-bottom)+1rem)] max-h-[75vh] overflow-y-auto">
                    <div class="flex items-center justify-between mb-3">
                        <h3 class="font-semibold text-slate-900">More</h3>
                        <button type="button" @click="moreSheetOpen = false"><Icon name="x-mark" class="h-5 w-5 text-slate-500" /></button>
                    </div>
                    <div class="grid grid-cols-3 gap-3">
                        <RouterLink
                            v-for="item in mobileMoreItems"
                            :key="item.name"
                            :to="{ name: item.name }"
                            class="flex flex-col items-center gap-1 p-3 rounded-lg text-slate-600 hover:bg-slate-50 text-xs"
                            @click="moreSheetOpen = false"
                        >
                            <Icon :name="item.icon" class="h-5 w-5" />
                            {{ item.label }}
                        </RouterLink>
                        <RouterLink
                            :to="{ name: 'profile' }"
                            class="flex flex-col items-center gap-1 p-3 rounded-lg text-slate-600 hover:bg-slate-50 text-xs"
                            @click="moreSheetOpen = false"
                        >
                            <Icon name="user-circle" class="h-5 w-5" />
                            Profile
                        </RouterLink>
                        <RouterLink
                            v-if="route.name !== 'contact'"
                            :to="{ name: 'contact' }"
                            class="flex flex-col items-center gap-1 p-3 rounded-lg text-slate-600 hover:bg-slate-50 text-xs"
                            @click="moreSheetOpen = false"
                        >
                            <Icon name="phone" class="h-5 w-5" />
                            Contact
                        </RouterLink>
                        <RouterLink
                            v-if="route.name !== 'privacy'"
                            :to="{ name: 'privacy' }"
                            class="flex flex-col items-center gap-1 p-3 rounded-lg text-slate-600 hover:bg-slate-50 text-xs"
                            @click="moreSheetOpen = false"
                        >
                            <Icon name="shield-check" class="h-5 w-5" />
                            Privacy
                        </RouterLink>
                        <button
                            type="button"
                            class="flex flex-col items-center gap-1 p-3 rounded-lg text-rose-600 hover:bg-rose-50 text-xs"
                            @click="handleLogout"
                        >
                            <Icon name="logout" class="h-5 w-5" />
                            Logout
                        </button>
                    </div>
                </div>
            </div>
        </Teleport>
    </div>
</template>
