import api from './api';

export default {
    list(params) {
        return api.get('/purchases', { params });
    },
    get(id) {
        return api.get(`/purchases/${id}`);
    },
    create(payload) {
        return api.post('/purchases', payload);
    },
    update(id, payload) {
        return api.put(`/purchases/${id}`, payload);
    },
    remove(id) {
        return api.delete(`/purchases/${id}`);
    },
};
