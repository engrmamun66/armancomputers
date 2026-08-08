import api from './api';

export default {
    list(params) {
        return api.get('/brands', { params });
    },
    all() {
        return api.get('/brands', { params: { per_page: 100 } });
    },
    create(payload) {
        return api.post('/brands', payload);
    },
    update(id, payload) {
        return api.put(`/brands/${id}`, payload);
    },
    remove(id) {
        return api.delete(`/brands/${id}`);
    },
};
