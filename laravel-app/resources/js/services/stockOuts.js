import api from './api';

export default {
    list(params) {
        return api.get('/stock-outs', { params });
    },
    get(id) {
        return api.get(`/stock-outs/${id}`);
    },
    create(payload) {
        return api.post('/stock-outs', payload);
    },
    update(id, payload) {
        return api.put(`/stock-outs/${id}`, payload);
    },
    remove(id) {
        return api.delete(`/stock-outs/${id}`);
    },
};
