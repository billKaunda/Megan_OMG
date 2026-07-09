import React, { useState } from 'react';
import './TransactionForm.css';
import { createWallet, fetchBalance } from '../api/blockchain.api';

const WalletPanel = () => {
  const [wallet, setWallet] = useState(null);
  const [balance, setBalance] = useState(null);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [copiedField, setCopiedField] = useState('');

  const handleCreateWallet = async () => {
    setLoading(true);
    setMessage('');

    try {
      const response = await createWallet();
      const walletData = response;
      setWallet(walletData);
      const balanceResponse = await fetchBalance(walletData.publicKey);
      setBalance(balanceResponse.balance);
      setMessage('Wallet created successfully');
    } catch (err) {
      setMessage(err.message || 'Failed to create wallet');
    } finally {
      setLoading(false);
    }
  };

  const handleCopy = async (value, fieldName) => {
    try {
      await navigator.clipboard.writeText(value);
      setCopiedField(fieldName);
      window.setTimeout(() => setCopiedField(''), 1500);
    } catch (error) {
      setMessage('Unable to copy to clipboard');
    }
  };

  return (
    <div className="transaction-form">
      <h2 className="panel-title">Wallet Studio</h2>
      <p className="panel-subtitle">Generate a key pair and inspect balance.</p>

      <button type="button" className="submit-button" onClick={handleCreateWallet} disabled={loading}>
        {loading ? 'Generating...' : 'Create Wallet'}
      </button>

      {message && <div className={`form-message ${message.includes('success') ? 'success' : 'error'}`}>{message}</div>}

      <div className="wallet-note">Tip: copy your keys before leaving the page.</div>

      {wallet && (
        <div className="form-group">
          <label>Public Key</label>
          <div className="value-row">
            <div className="field-value hash">{wallet.publicKey}</div>
            <button type="button" className="copy-button" onClick={() => handleCopy(wallet.publicKey, 'publicKey')}>
              {copiedField === 'publicKey' ? 'Copied!' : 'Copy'}
            </button>
          </div>

          <label>Private Key</label>
          <div className="value-row">
            <div className="field-value hash">{wallet.privateKey}</div>
            <button type="button" className="copy-button" onClick={() => handleCopy(wallet.privateKey, 'privateKey')}>
              {copiedField === 'privateKey' ? 'Copied!' : 'Copy'}
            </button>
          </div>

          <label>Balance</label>
          <div className="value-row">
            <div className="field-value">{balance}</div>
            <button type="button" className="copy-button" onClick={() => handleCopy(String(balance), 'balance')} disabled={balance === null}>
              {copiedField === 'balance' ? 'Copied!' : 'Copy'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default WalletPanel;
