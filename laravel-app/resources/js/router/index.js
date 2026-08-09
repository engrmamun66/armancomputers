import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '@/stores/auth';

const routes = [
    {
        path: '/login',
        name: 'login',
        component: () => import('@/views/auth/Login.vue'),
        meta: { guestOnly: true },
    },
    {
        path: '/',
        redirect: { name: 'dashboard' },
    },
    {
        path: '/dashboard',
        name: 'dashboard',
        component: () => import('@/views/dashboard/Dashboard.vue'),
        meta: { requiresAuth: true },
    },
    {
        path: '/products',
        name: 'products.index',
        component: () => import('@/views/products/ProductList.vue'),
        meta: { requiresAuth: true },
    },
    {
        path: '/products/create',
        name: 'products.create',
        component: () => import('@/views/products/ProductForm.vue'),
        meta: { requiresAuth: true, roles: ['admin', 'manager'] },
    },
    {
        path: '/products/:id/edit',
        name: 'products.edit',
        component: () => import('@/views/products/ProductForm.vue'),
        meta: { requiresAuth: true, roles: ['admin', 'manager'] },
        props: true,
    },
    {
        path: '/products/:id',
        name: 'products.show',
        component: () => import('@/views/products/ProductShow.vue'),
        meta: { requiresAuth: true },
        props: true,
    },
    {
        path: '/products/:id/stock-history',
        name: 'products.stock-history',
        component: () => import('@/views/products/StockHistory.vue'),
        meta: { requiresAuth: true },
        props: true,
    },
    {
        path: '/brands',
        name: 'brands.index',
        component: () => import('@/views/brands/BrandList.vue'),
        meta: { requiresAuth: true, roles: ['admin', 'manager'] },
    },
    {
        path: '/customers',
        name: 'customers.index',
        component: () => import('@/views/customers/CustomerList.vue'),
        meta: { requiresAuth: true },
    },
    {
        path: '/customers/:id',
        name: 'customers.show',
        component: () => import('@/views/customers/CustomerShow.vue'),
        meta: { requiresAuth: true },
        props: true,
    },
    {
        path: '/purchases',
        name: 'purchases.index',
        component: () => import('@/views/purchases/PurchaseList.vue'),
        meta: { requiresAuth: true, roles: ['admin', 'manager'] },
    },
    {
        path: '/purchases/create',
        name: 'purchases.create',
        component: () => import('@/views/purchases/PurchaseForm.vue'),
        meta: { requiresAuth: true, roles: ['admin', 'manager'] },
    },
    {
        path: '/purchases/:id/edit',
        name: 'purchases.edit',
        component: () => import('@/views/purchases/PurchaseForm.vue'),
        meta: { requiresAuth: true, roles: ['admin', 'manager'] },
        props: true,
    },
    {
        path: '/purchases/:id',
        name: 'purchases.show',
        component: () => import('@/views/purchases/PurchaseShow.vue'),
        meta: { requiresAuth: true, roles: ['admin', 'manager'] },
        props: true,
    },
    {
        path: '/sales',
        name: 'sales.index',
        component: () => import('@/views/sales/SaleList.vue'),
        meta: { requiresAuth: true },
    },
    {
        path: '/sales/create',
        name: 'sales.create',
        component: () => import('@/views/sales/SaleForm.vue'),
        meta: { requiresAuth: true },
    },
    {
        path: '/sales/:id/edit',
        name: 'sales.edit',
        component: () => import('@/views/sales/SaleForm.vue'),
        meta: { requiresAuth: true, roles: ['admin', 'manager'] },
        props: true,
    },
    {
        path: '/sales/:id',
        name: 'sales.show',
        component: () => import('@/views/sales/SaleShow.vue'),
        meta: { requiresAuth: true },
        props: true,
    },
    {
        path: '/invoices',
        name: 'invoices.index',
        component: () => import('@/views/invoices/InvoiceList.vue'),
        meta: { requiresAuth: true },
    },
    {
        path: '/invoices/:id',
        name: 'invoices.show',
        component: () => import('@/views/invoices/InvoiceShow.vue'),
        meta: { requiresAuth: true },
        props: true,
    },
    {
        path: '/users',
        name: 'users.index',
        component: () => import('@/views/users/UserList.vue'),
        meta: { requiresAuth: true, roles: ['admin'] },
    },
    {
        path: '/profile',
        name: 'profile',
        component: () => import('@/views/profile/Profile.vue'),
        meta: { requiresAuth: true },
    },
    {
        path: '/contact',
        name: 'contact',
        component: () => import('@/views/contact/Contact.vue'),
        meta: { requiresAuth: true },
    },
    {
        path: '/privacy-policy',
        name: 'privacy',
        component: () => import('@/views/privacy/PrivacyPolicy.vue'),
        meta: { requiresAuth: true },
    },
    {
        path: '/:pathMatch(.*)*',
        name: 'not-found',
        component: () => import('@/views/NotFound.vue'),
    },
];

const router = createRouter({
    history: createWebHistory(),
    routes,
    scrollBehavior: () => ({ top: 0 }),
});

router.beforeEach((to) => {
    const auth = useAuthStore();

    if (to.meta.guestOnly && auth.isAuthenticated) {
        return { name: 'dashboard' };
    }

    if (to.meta.requiresAuth && !auth.isAuthenticated) {
        return { name: 'login', query: { redirect: to.fullPath } };
    }

    if (to.meta.roles && !auth.hasRole(...to.meta.roles)) {
        return { name: 'dashboard' };
    }

    return true;
});

export default router;
