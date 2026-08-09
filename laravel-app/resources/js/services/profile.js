import api from './api';

export default {
    update(payload) {
        return api.put('/profile', payload);
    },
    updateAvatar(file) {
        const formData = new FormData();
        formData.append('avatar', file);
        return api.post('/profile/avatar', formData, { headers: { 'Content-Type': 'multipart/form-data' } });
    },
    updatePassword(payload) {
        return api.put('/profile/password', payload);
    },
};
