import api from './api';

export default {
    list(params) {
        return api.get('/products', { params });
    },
    get(id) {
        return api.get(`/products/${id}`);
    },
    create(payload) {
        return api.post('/products', payload);
    },
    update(id, payload) {
        return api.put(`/products/${id}`, payload);
    },
    remove(id) {
        return api.delete(`/products/${id}`);
    },
    stockHistory(id) {
        return api.get(`/products/${id}/stock-history`);
    },
};
