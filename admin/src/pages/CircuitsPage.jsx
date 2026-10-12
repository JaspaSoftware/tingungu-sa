import { useState, useEffect } from 'react';
import { FiPlus, FiTrash2, FiLayers } from 'react-icons/fi';
import { API_BASE_URL } from '../config';
import { apiFetch } from '../api';

function Modal({ title, onClose, onSave, loading, children }) {
  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <div className="modal-header">
          <h3>{title}</h3>
          <button className="btn-close" onClick={onClose}>âœ•</button>
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

export default function CircuitsPage() {
  const [circuits, setCircuits] = useState([]);
  const [districts, setDistricts] = useState([]);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ code: '', name: '', district_id: '' });
  const [loading, setLoading] = useState(false);

  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    fetchCircuits();
    fetchDistricts();
  }, []);

  const fetchCircuits = async () => {
    try {
      const res = await apiFetch(`${API_BASE_URL}/circuits`);
      const data = await res.json();
      setCircuits(data);
    } catch (err) {
      console.error('Error fetching circuits:', err);
    }
  };

  const fetchDistricts = async () => {
    try {
      const res = await apiFetch(`${API_BASE_URL}/districts`);
      const data = await res.json();
      setDistricts(data);
      if (data.length > 0) setForm(f => ({ ...f, district_id: data[0].district_id }));
    } catch (err) {
      console.error('Error fetching districts:', err);
    }
  };

  const save = async () => {
    if (!form.name || !form.code || !form.district_id) return;
    setLoading(true);
    try {
      const res = await apiFetch(`${API_BASE_URL}/circuits`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      if (res.ok) {
        fetchCircuits();
        setShowModal(false);
        setForm({ code: '', name: '', district_id: districts[0]?.district_id || '' });
      }
    } finally {
      setLoading(false);
    }
  };

  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentItems = circuits.slice(indexOfFirstItem, indexOfLastItem);
  const totalPages = Math.ceil(circuits.length / itemsPerPage);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Circuits</h1>
          <p>Manage church circuits</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowModal(true)}><FiPlus /> Add Circuit</button>
      </div>

      <div className="card">
        {circuits.length === 0 ? (
          <div className="empty-state">
            <FiLayers />
            <h3>No circuits</h3>
            <p>Add church circuits to the database</p>
          </div>
        ) : (
          <>
            <div className="table-container">
              <table>
                <thead>
                  <tr>
                    <th>Code</th>
                    <th>Circuit Name</th>
                    <th>District</th>
                  </tr>
                </thead>
                <tbody>
                  {currentItems.map(c => (
                    <tr key={c.circuit_id}>
                      <td><span className="badge badge-outline">#{c.circuit_code}</span></td>
                      <td><strong>{c.circuit_name}</strong></td>
                      <td>{c.district_name || 'â€”'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {totalPages > 1 && (
              <div className="pagination">
                <button 
                  className="btn btn-outline btn-sm" 
                  disabled={currentPage === 1}
                  onClick={() => setCurrentPage(prev => prev - 1)}
                >
                  Previous
                </button>
                <span className="pagination-info">Page {currentPage} of {totalPages}</span>
                <button 
                  className="btn btn-outline btn-sm" 
                  disabled={currentPage === totalPages}
                  onClick={() => setCurrentPage(prev => prev + 1)}
                >
                  Next
                </button>
              </div>
            )}
          </>
        )}
      </div>

      {showModal && (
        <Modal title="Add Circuit" onClose={() => setShowModal(false)} onSave={save} loading={loading}>
          <div className="form-group">
            <label className="form-label">Circuit Code</label>
            <input 
              className="form-control" 
              placeholder="e.g. 1101" 
              value={form.code} 
              onChange={e => setForm(f => ({ ...f, code: e.target.value }))} 
            />
          </div>
          <div className="form-group">
            <label className="form-label">Circuit Name</label>
            <input 
              className="form-control" 
              placeholder="e.g. Central" 
              value={form.name} 
              onChange={e => setForm(f => ({ ...f, name: e.target.value }))} 
            />
          </div>
          <div className="form-group">
            <label className="form-label">District</label>
            <select 
              className="form-control" 
              value={form.district_id} 
              onChange={e => setForm(f => ({ ...f, district_id: e.target.value }))}
            >
              {districts.map(d => (
                <option key={d.district_id} value={d.district_id}>
                  {d.district_name}
                </option>
              ))}
            </select>
          </div>
        </Modal>
      )}
    </div>
  );
}
