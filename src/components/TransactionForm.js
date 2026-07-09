import React, { useState } from 'react';
import './TransactionForm.css';
import { addTransaction } from '../api/blockchain.api';

const TransactionForm = ({ onTransactionAdded }) => {
  const [formData, setFormData] = useState({
    fromAddress: '',
    toAddress: '',
    amount: '',
  });
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    setMessage('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMessage('');

    try {
      await addTransaction(formData.fromAddress, formData.toAddress, formData.amount);
      setMessage('Transaction added successfully!');
      setFormData({ fromAddress: '', toAddress: '', amount: '' });
      onTransactionAdded();
    } catch (err) {
      setMessage(err.message || 'Failed to add transaction');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="transaction-form">
      <h2 className="panel-title">Create Transaction</h2>
      
      <form onSubmit={handleSubmit}>
        <p className="panel-subtitle">Use a wallet public key and a signed transaction payload to test the blockchain flow.</p>

        <div className="form-group">
          <label htmlFor="fromAddress">From Address</label>
          <input
            type="text"
            id="fromAddress"
            name="fromAddress"
            value={formData.fromAddress}
            onChange={handleChange}
            placeholder="e.g., wallet-public-key"
            required
          />
        </div>
        
        <div className="form-group">
          <label htmlFor="toAddress">To Address</label>
          <input
            type="text"
            id="toAddress"
            name="toAddress"
            value={formData.toAddress}
            onChange={handleChange}
            placeholder="e.g., wallet-public-key"
            required
          />
        </div>
        
        <div className="form-group">
          <label htmlFor="amount">Amount</label>
          <input
            type="number"
            id="amount"
            name="amount"
            value={formData.amount}
            onChange={handleChange}
            placeholder="e.g., 100"
            step="0.01"
            min="0"
            required
          />
        </div>
        
        {message && (
          <div className={`form-message ${message.includes('success') ? 'success' : 'error'}`}>
            {message}
          </div>
        )}
        
        <button type="submit" className="submit-button" disabled={loading}>
          {loading ? 'Adding...' : 'Add Transaction'}
        </button>
      </form>
    </div>
  );
};

export default TransactionForm;
