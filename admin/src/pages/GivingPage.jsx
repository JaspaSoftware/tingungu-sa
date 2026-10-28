import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, onSnapshot } from 'firebase/firestore';
import { FiPlus, FiTrash2, FiEdit2, FiHeart } from 'react-icons/fi';
import { API_BASE_URL } from '../config';
import { apiFetch } from '../api';

function Modal({ title, onClose, onSave, loading, children }) {
  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <div className="modal-header">
          <h3>{title}</h3>
          <button className="btn-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">{children}</div>
        <div className="modal-footer">
          <button className="btn btn-outline" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={onSave} disabled={loading}>
            {loading ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function GivingPage() {
  const [options, setOptions] = useState([]);
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState({ name: '', description: '', minAmount: '', maxAmount: '', active: true });
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    return onSnapshot(collection(db, 'giving_options'), snap => {
      setOptions(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
  }, []);

  const openNew = () => { setEditing(null); setForm({ name: '', description: '', minAmount: '', maxAmount: '', active: true }); setShowModal(true); };
  const openEdit = (o) => { setEditing(o); setForm({ name: o.name, description: o.description || '', minAmount: o.minAmount || '', maxAmount: o.maxAmount || '', active: o.active !== false }); setShowModal(true); };

  const save = async () => {
    if (!form.name) return;
    setLoading(true);
    const data = { name: form.name, description: form.description, minAmount: Number(form.minAmount) || 0, maxAmount: Number(form.maxAmount) || 0, active: form.active };
    try {
      const response = await apiFetch(
        `${API_BASE_URL}/giving-options${editing ? `/${encodeURIComponent(editing.id)}` : ''}`,
        {
          method: editing ? 'PUT' : 'POST',
          body: JSON.stringify(data),
        },
      );
      if (!response.ok) {
        const result = await response.json().catch(() => ({}));
        throw new Error(result.error || 'Failed to save giving option.');
      }
      setShowModal(false);
    } catch (error) {
      alert(error.message || 'Failed to save giving option.');
    } finally {
      setLoading(false);
    }
  };

  const remove = async (id) => {
    if (!confirm('Delete this giving option?')) return;
    try {
      const response = await apiFetch(
        `${API_BASE_URL}/giving-options/${encodeURIComponent(id)}`,
        { method: 'DELETE' },
      );
      if (!response.ok) {
        const result = await response.json().catch(() => ({}));
        throw new Error(result.error || 'Failed to delete giving option.');
      }
    } catch (error) {
      alert(error.message || 'Failed to delete giving option.');
    }
  };

  const toggleActive = async (o) => {
    try {
      const response = await apiFetch(
        `${API_BASE_URL}/giving-options/${encodeURIComponent(o.id)}`,
        {
          method: 'PUT',
          body: JSON.stringify({
            name: o.name,
            description: o.description || '',
            minAmount: o.minAmount || 0,
            maxAmount: o.maxAmount || 0,
            active: !o.active,
          }),
        },
      );
      if (!response.ok) {
        const result = await response.json().catch(() => ({}));
        throw new Error(result.error || 'Failed to update giving option.');
      }
    } catch (error) {
      alert(error.message || 'Failed to update giving option.');
    }
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Giving Options</h1>
          <p>Manage tithes, offerings, pledges and donations available in the app</p>
        </div>
        <button className="btn btn-primary" onClick={openNew}>
          <FiPlus /> Add Option
        </button>
      </div>

      <div className="card">
        {options.length === 0 ? (
          <div className="empty-state">
            <FiHeart />
            <h3>No giving options</h3>
            <p>Add tithes, pledges, or donation categories for members</p>
          </div>
        ) : (
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Description</th>
                  <th>Min (R)</th>
                  <th>Max (R)</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {options.map(o => (
                  <tr key={o.id}>
                    <td><strong>{o.name}</strong></td>
                    <td style={{ color: 'var(--text-secondary)', maxWidth: 240 }} className="truncate">{o.description || '—'}</td>
                    <td>{o.minAmount ? `R ${o.minAmount}` : 'Any'}</td>
                    <td>{o.maxAmount ? `R ${o.maxAmount}` : 'No limit'}</td>
                    <td>
                      <span className={`badge ${o.active !== false ? 'badge-success' : 'badge-neutral'}`} style={{ cursor: 'pointer' }} onClick={() => toggleActive(o)}>
                        {o.active !== false ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button className="btn btn-outline btn-sm btn-icon" onClick={() => openEdit(o)}><FiEdit2 size={14} /></button>
                        <button className="btn btn-danger btn-sm btn-icon" onClick={() => remove(o.id)}><FiTrash2 size={14} /></button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {showModal && (
        <Modal title={editing ? 'Edit Giving Option' : 'New Giving Option'} onClose={() => setShowModal(false)} onSave={save} loading={loading}>
          <div className="form-group">
            <label className="form-label">Name</label>
            <input className="form-control" placeholder="e.g. Tithes, Pledge for Building Fund" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
          </div>
          <div className="form-group">
            <label className="form-label">Description</label>
            <textarea className="form-control" placeholder="Brief description..." value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} rows={2} />
          </div>
          <div className="form-row">
            <div className="form-group">
              <label className="form-label">Min Amount (R)</label>
              <input type="number" className="form-control" placeholder="0 = any" value={form.minAmount} onChange={e => setForm(f => ({ ...f, minAmount: e.target.value }))} />
            </div>
            <div className="form-group">
              <label className="form-label">Max Amount (R)</label>
              <input type="number" className="form-control" placeholder="0 = no limit" value={form.maxAmount} onChange={e => setForm(f => ({ ...f, maxAmount: e.target.value }))} />
            </div>
          </div>
          <div className="form-group" style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <input type="checkbox" id="activeCheck" checked={form.active} onChange={e => setForm(f => ({ ...f, active: e.target.checked }))} />
            <label htmlFor="activeCheck" className="form-label" style={{ marginBottom: 0 }}>Active (visible in app)</label>
          </div>
        </Modal>
      )}
    </div>
  );
}
