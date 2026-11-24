import React, { createContext, useContext, useState, useCallback } from 'react';
import axiosClient from '../api/axiosClient';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const token = localStorage.getItem('accessToken');
    return token ? decodeUser(token) : null;
  });

  const login = useCallback(async (email, password) => {
    const { data } = await axiosClient.post('/auth/login', { email, password });
    localStorage.setItem('accessToken', data.accessToken);
    localStorage.setItem('refreshToken', data.refreshToken);
    setUser(decodeUser(data.accessToken));
  }, []);

  const register = useCallback(async (email, password) => {
    const { data } = await axiosClient.post('/auth/register', { email, password });
    localStorage.setItem('accessToken', data.accessToken);
    localStorage.setItem('refreshToken', data.refreshToken);
    setUser(decodeUser(data.accessToken));
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider value={{ user, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}

// Decodes the JWT payload client-side JUST to read email/role for display.
// This is not a security boundary - the backend re-validates the signature
// on every request. Never trust a client-decoded token for access control.
function decodeUser(token) {
  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    return { id: payload.sub, email: payload.email, role: payload.role };
  } catch {
    return null;
  }
}