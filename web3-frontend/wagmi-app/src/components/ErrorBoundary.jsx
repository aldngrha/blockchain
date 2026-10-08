import { Component } from "react";

/*
 * ERROR BOUNDARY
 *
 * Tanpa ErrorBoundary:
 *   → Component crash → SEMUA app hilang (blank screen)
 *   → User gak tau kenapa
 *   → Hard refresh = lose state
 *
 * Dengan ErrorBoundary:
 *   → Component crash → error message tampil
 *   → Sisa app masih jalan
 *   → Tombol "Try Again" buat retry
 *
 * Kenapa class component?
 *   → React gak support error boundary di functional component
 *   → Ini salah satu dari 3 use case class component (sama-sama error boundary)
 */
export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null, errorInfo: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    this.setState({ errorInfo });
    // Log ke error service (Sentry, LogRocket, dll) di production
    console.error("ErrorBoundary caught:", error, errorInfo);
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null, errorInfo: null });
  };

  render() {
    if (this.state.hasError) {
      return (
        <div style={styles.container}>
          <div style={styles.card}>
            <h2 style={styles.title}>⚠️ Something went wrong</h2>
            <p style={styles.message}>
              {this.state.error?.message || "An unexpected error occurred"}
            </p>

            {this.state.errorInfo && (
              <details style={styles.details}>
                <summary style={styles.summary}>Error Details</summary>
                <pre style={styles.stack}>
                  {this.state.error?.stack}
                </pre>
                <pre style={styles.stack}>
                  {this.state.errorInfo.componentStack}
                </pre>
              </details>
            )}

            <button onClick={this.handleRetry} style={styles.button}>
              🔄 Try Again
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

const styles = {
  container: {
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    minHeight: "200px",
    padding: "2rem",
  },
  card: {
    background: "#16213e",
    border: "1px solid #e74c3c",
    borderRadius: "12px",
    padding: "2rem",
    textAlign: "center",
    maxWidth: "500px",
  },
  title: {
    color: "#e74c3c",
    marginBottom: "1rem",
  },
  message: {
    color: "#e0e0e0",
    marginBottom: "1rem",
  },
  details: {
    textAlign: "left",
    marginBottom: "1rem",
  },
  summary: {
    color: "#f39c12",
    cursor: "pointer",
    marginBottom: "0.5rem",
  },
  stack: {
    background: "#0f3460",
    padding: "0.75rem",
    borderRadius: "8px",
    fontSize: "0.75rem",
    color: "#888",
    overflow: "auto",
    maxHeight: "150px",
    marginTop: "0.5rem",
  },
  button: {
    background: "#e94560",
    color: "white",
    border: "none",
    borderRadius: "8px",
    padding: "0.6rem 1.2rem",
    fontSize: "1rem",
    cursor: "pointer",
  },
};
