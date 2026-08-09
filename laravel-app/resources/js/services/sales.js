import api from './api';

export default {
    list(params) {
        return api.get('/sales', { params });
    },
    get(id) {
        return api.get(`/sales/${id}`);
    },
    create(payload) {
        return api.post('/sales', payload);
    },
    update(id, payload) {
        return api.put(`/sales/${id}`, payload);
    },
    remove(id) {
        return api.delete(`/sales/${id}`);
    },
};
