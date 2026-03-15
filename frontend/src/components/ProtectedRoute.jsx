import { Navigate } from 'react-router-dom';

/**
 * ProtectedRoute — wraps child components and redirects to /login
 * if no valid JWT token exists in localStorage.
 */
export default function ProtectedRoute({ children }) {
  const token = localStorage.getItem('token');

  if (!token) {
    return <Navigate to="/login" replace />;
  }

  return children;
}
