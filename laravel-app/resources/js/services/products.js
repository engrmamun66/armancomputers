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
    uploadImage(productId, formData) {
        return api.post(`/products/${productId}/images`, formData, {
            headers: { 'Content-Type': 'multipart/form-data' },
        });
    },
    deleteImage(productId, imageId) {
        return api.delete(`/products/${productId}/images/${imageId}`);
    },
    setDefaultImage(productId, imageId) {
        return api.patch(`/products/${productId}/images/${imageId}/default`);
    },
};
