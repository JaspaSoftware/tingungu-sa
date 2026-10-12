import { useState, useEffect } from 'react';
import { FiPlus, FiTrash2, FiMap } from 'react-icons/fi';
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

export default function DistrictsPage() {
  const [districts, setDistricts] = useState([]);
  const [showModal, setShowModal] = useState(false);
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(false);

  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    fetchDistricts();
  }, []);

  const fetchDistricts = async () => {
    try {
      const res = await apiFetch(`${API_BASE_URL}/districts`);
      const data = await res.json();
      setDistricts(data);
    } catch (err) {
      console.error('Error fetching districts:', err);
    }
  };

  const save = async () => {
    if (!name) return;
    setLoading(true);
    try {
      const res = await apiFetch(`${API_BASE_URL}/districts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name }),
      });
      if (res.ok) {
        fetchDistricts();
        setShowModal(false);
        setName('');
      }
    } finally {
      setLoading(false);
    }
  };

  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentItems = districts.slice(indexOfFirstItem, indexOfLastItem);
  const totalPages = Math.ceil(districts.length / itemsPerPage);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Districts</h1>
          <p>Manage church districts</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowModal(true)}><FiPlus /> Add District</button>
      </div>

      <div className="card">
        {districts.length === 0 ? (
          <div className="empty-state">
            <FiMap />
            <h3>No districts</h3>
            <p>Add church districts to the database</p>
          </div>
        ) : (
          <>
            <div className="table-container">
              <table>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>District Name</th>
                  </tr>
                </thead>
                <tbody>
                  {currentItems.map(d => (
                    <tr key={d.district_id}>
                      <td><span className="badge badge-outline">#{d.district_id}</span></td>
                      <td><strong>{d.district_name}</strong></td>
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
        <Modal title="Add District" onClose={() => setShowModal(false)} onSave={save} loading={loading}>
          <div className="form-group">
            <label className="form-label">District Name</label>
            <input 
              className="form-control" 
              placeholder="e.g. Limpopo" 
              value={name} 
              onChange={e => setName(e.target.value)} 
            />
          </div>
        </Modal>
      )}
    </div>
  );
}
