import { useState, useEffect } from "react";

/*
 * TOAST NOTIFICATION SYSTEM
 *
 * Kenapa toast?
 * → Transaksi blockchain itu LAMBAT (12-60 detik)
 * → User harus tau statusnya kapanpun, di mana pun di page
 * → Alert() jelek, block UI, gak bisa di-stack
 * → Toast = notification kecil yang muncul di corner
 *     → Auto-dismiss setelah beberapa detik
 *     → Bisa stack (beberapa notif sekaligus)
 *     → Non-blocking (user bisa tetap interaksi)
 */

let toastId = 0;

export function useToast() {
  const [toasts, setToasts] = useState([]);

  const addToast = (message, type = "info", duration = 5000) => {
    const id = ++toastId;
    setToasts((prev) => [...prev, { id, message, type }]);

    // Auto-remove setelah duration
    if (duration > 0) {
      setTimeout(() => {
        setToasts((prev) => prev.filter((t) => t.id !== id));
      }, duration);
    }
  };

  const removeToast = (id) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  return { toasts, addToast, removeToast };
}

// Toast container component
export function ToastContainer({ toasts, onRemove }) {
  return (
    <div className="toast-container">
      {toasts.map((toast) => (
        <div key={toast.id} className={`toast toast-${toast.type}`}>
          <span className="toast-icon">
            {toast.type === "success" && "✅"}
            {toast.type === "error" && "❌"}
            {toast.type === "pending" && "⏳"}
            {toast.type === "info" && "ℹ️"}
          </span>
          <span className="toast-message">{toast.message}</span>
          <button className="toast-close" onClick={() => onRemove(toast.id)}>
            ×
          </button>
        </div>
      ))}
    </div>
  );
}
