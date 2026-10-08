import { useState } from "react";

// ═══════════════════════════════════════════════
// IPFS + PINATA — Upload file ke decentralized storage
// ═══════════════════════════════════════════════

const PINATA_API_URL = "https://api.pinata.cloud";
const PINATA_GATEWAY = "https://gateway.pinata.cloud/ipfs";

export default function IPFSDemo() {
  const [apiKey, setApiKey] = useState("");
  const [apiSecret, setApiSecret] = useState("");

  // Upload state
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [uploadResult, setUploadResult] = useState(null);

  // JSON metadata state
  const [metadataName, setMetadataName] = useState("My NFT");
  const [metadataDescription, setMetadataDescription] = useState("A test NFT metadata");
  const [metadataImage, setMetadataImage] = useState("");
  const [jsonResult, setJsonResult] = useState(null);
  const [jsonUploading, setJsonUploading] = useState(false);

  // Gateway test
  const [testCid, setTestCid] = useState("");
  const [testResult, setTestResult] = useState(null);

  // ─── UPLOAD FILE ──────────────────────────
  const handleUploadFile = async () => {
    if (!file || !apiKey || !apiSecret) return;
    setUploading(true);
    setUploadResult(null);

    try {
      const formData = new FormData();
      formData.append("file", file);

      const pinataOptions = JSON.stringify({
        cidVersion: 1,
      });
      formData.append("pinataOptions", pinataOptions);

      const metadata = JSON.stringify({
        name: file.name,
      });
      formData.append("pinataMetadata", metadata);

      const res = await fetch(`${PINATA_API_URL}/pinning/pinFileToIPFS`, {
        method: "POST",
        headers: {
          pinata_api_key: apiKey,
          pinata_secret_api_key: apiSecret,
        },
        body: formData,
      });

      const data = await res.json();
      if (data.IpfsHash) {
        setUploadResult({
          cid: data.IpfsHash,
          size: data.PinSize,
          timestamp: data.Timestamp,
          gatewayUrl: `${PINATA_GATEWAY}/${data.IpfsHash}`,
        });
      } else {
        setUploadResult({ error: data.message || "Upload failed" });
      }
    } catch (err) {
      setUploadResult({ error: err.message });
    } finally {
      setUploading(false);
    }
  };

  // ─── UPLOAD JSON METADATA ─────────────────
  const handleUploadJson = async () => {
    if (!apiKey || !apiSecret) return;
    setJsonUploading(true);
    setJsonResult(null);

    const metadataJson = {
      name: metadataName,
      description: metadataDescription,
      image: metadataImage || "ipfs://QmYourImageCidHere",
      attributes: [
        { trait_type: "Rarity", value: "Common" },
        { trait_type: "Power", value: 50 },
      ],
    };

    try {
      const res = await fetch(`${PINATA_API_URL}/pinning/pinJSONToIPFS`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          pinata_api_key: apiKey,
          pinata_secret_api_key: apiSecret,
        },
        body: JSON.stringify({
          pinataContent: metadataJson,
          pinataMetadata: {
            name: `${metadataName}_metadata.json`,
          },
        }),
      });

      const data = await res.json();
      if (data.IpfsHash) {
        setJsonResult({
          cid: data.IpfsHash,
          size: data.PinSize,
          gatewayUrl: `${PINATA_GATEWAY}/${data.IpfsHash}`,
          content: metadataJson,
        });
      } else {
        setJsonResult({ error: data.message || "Upload failed" });
      }
    } catch (err) {
      setJsonResult({ error: err.message });
    } finally {
      setJsonUploading(false);
    }
  };

  // ─── TEST GATEWAY ─────────────────────────
  const handleTestGateway = async () => {
    if (!testCid) return;
    setTestResult(null);

    try {
      const url = `${PINATA_GATEWAY}/${testCid}`;
      const res = await fetch(url);
      const contentType = res.headers.get("content-type");
      let content;

      if (contentType?.includes("application/json")) {
        content = await res.json();
      } else {
        content = await res.text();
      }

      setTestResult({
        url,
        status: res.status,
        contentType,
        content,
      });
    } catch (err) {
      setTestResult({ error: err.message });
    }
  };

  // ─── RENDER ───────────────────────────────
  return (
    <section className="card ipfs-demo">
      <h2>6. IPFS + Pinata — Decentralized Storage</h2>
      <p className="graphql-subtitle">
        Upload file ke IPFS via Pinata — gateway accessible dari mana aja
      </p>

      {/* API KEY INPUT */}
      <div className="ipfs-api-section">
        <h3>🔑 Pinata API Keys</h3>
        <p className="graphql-subtitle">
          Dapatkan di{" "}
          <a href="https://app.pinata.cloud/developers/api-keys" target="_blank" rel="noopener noreferrer">
            pinata.cloud/developers/api-keys
          </a>
        </p>
        <div className="ipfs-key-inputs">
          <input
            type="text"
            placeholder="API Key"
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
            className="search-input"
          />
          <input
            type="password"
            placeholder="API Secret"
            value={apiSecret}
            onChange={(e) => setApiSecret(e.target.value)}
            className="search-input"
          />
        </div>
      </div>

      {/* UPLOAD FILE */}
      <div className="ipfs-section">
        <h3>📤 Upload File ke IPFS</h3>
        <div className="ipfs-upload-area">
          <input
            type="file"
            onChange={(e) => setFile(e.target.files[0])}
            className="ipfs-file-input"
          />
          <button
            className="btn btn-primary"
            onClick={handleUploadFile}
            disabled={!file || !apiKey || !apiSecret || uploading}
          >
            {uploading ? "⏳ Uploading..." : "📤 Upload to IPFS"}
          </button>
        </div>

        {uploadResult && !uploadResult.error && (
          <div className="ipfs-result success">
            <p>✅ <strong>Uploaded!</strong></p>
            <p><strong>CID:</strong> <code>{uploadResult.cid}</code></p>
            <p><strong>Size:</strong> {uploadResult.size} bytes</p>
            <p><strong>Gateway URL:</strong></p>
            <a href={uploadResult.gatewayUrl} target="_blank" rel="noopener noreferrer" className="ipfs-link">
              {uploadResult.gatewayUrl}
            </a>
          </div>
        )}

        {uploadResult?.error && (
          <div className="ipfs-result error">
            <p>❌ Error: {uploadResult.error}</p>
          </div>
        )}
      </div>

      {/* UPLOAD JSON METADATA */}
      <div className="ipfs-section">
        <h3>📋 Upload NFT Metadata (JSON)</h3>
        <div className="ipfs-json-form">
          <input
            type="text"
            placeholder="Name: My NFT"
            value={metadataName}
            onChange={(e) => setMetadataName(e.target.value)}
            className="search-input"
          />
          <input
            type="text"
            placeholder="Description"
            value={metadataDescription}
            onChange={(e) => setMetadataDescription(e.target.value)}
            className="search-input"
          />
          <input
            type="text"
            placeholder="Image CID: ipfs://Qm..."
            value={metadataImage}
            onChange={(e) => setMetadataImage(e.target.value)}
            className="search-input"
          />
          <button
            className="btn btn-primary"
            onClick={handleUploadJson}
            disabled={!apiKey || !apiSecret || jsonUploading}
          >
            {jsonUploading ? "⏳ Uploading..." : "📋 Upload JSON Metadata"}
          </button>
        </div>

        {jsonResult && !jsonResult.error && (
          <div className="ipfs-result success">
            <p>✅ <strong>Metadata Uploaded!</strong></p>
            <p><strong>CID:</strong> <code>{jsonResult.cid}</code></p>
            <p><strong>Gateway URL:</strong></p>
            <a href={jsonResult.gatewayUrl} target="_blank" rel="noopener noreferrer" className="ipfs-link">
              {jsonResult.gatewayUrl}
            </a>
            <details>
              <summary>📄 JSON Content</summary>
              <pre className="ipfs-json-preview">
                {JSON.stringify(jsonResult.content, null, 2)}
              </pre>
            </details>
            <p className="ipfs-usage">
              <strong>Cara pakai di smart contract:</strong><br />
              <code>tokenURI = "ipfs://{jsonResult.cid}"</code>
            </p>
          </div>
        )}

        {jsonResult?.error && (
          <div className="ipfs-result error">
            <p>❌ Error: {jsonResult.error}</p>
          </div>
        )}
      </div>

      {/* TEST GATEWAY */}
      <div className="ipfs-section">
        <h3>🔍 Test IPFS Gateway</h3>
        <div className="search-bar">
          <input
            type="text"
            placeholder="Paste CID: Qm..."
            value={testCid}
            onChange={(e) => setTestCid(e.target.value)}
            className="search-input"
          />
          <button className="btn btn-primary" onClick={handleTestGateway} disabled={!testCid}>
            🔍 Fetch
          </button>
        </div>

        {testResult && !testResult.error && (
          <div className="ipfs-result success">
            <p>✅ <strong>Status:</strong> {testResult.status}</p>
            <p><strong>Content-Type:</strong> {testResult.contentType}</p>
            <p><strong>URL:</strong> <a href={testResult.url} target="_blank" rel="noopener noreferrer">{testResult.url}</a></p>
            <details>
              <summary>📄 Content</summary>
              <pre className="ipfs-json-preview">
                {typeof testResult.content === "object"
                  ? JSON.stringify(testResult.content, null, 2)
                  : String(testResult.content).slice(0, 1000)}
              </pre>
            </details>
          </div>
        )}

        {testResult?.error && (
          <div className="ipfs-result error">
            <p>❌ Error: {testResult.error}</p>
          </div>
        )}
      </div>
    </section>
  );
}
