import { useState, useEffect } from 'react';
import { FiPlus, FiUser } from 'react-icons/fi';
import { API_BASE_URL } from '../config';
import { apiFetch } from '../api';

export default function MinistersPage() {
  const [ministers, setMinisters] = useState([]);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    fetchMinisters();
  }, []);

  const fetchMinisters = async () => {
    try {
      const res = await apiFetch(`${API_BASE_URL}/ministers`);
      const data = await res.json();
      setMinisters(data);
    } catch (err) {
      console.error('Error fetching ministers:', err);
    }
  };

  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentItems = ministers.slice(indexOfFirstItem, indexOfLastItem);
  const totalPages = Math.ceil(ministers.length / itemsPerPage);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Ministers & Appointments</h1>
          <p>View church ministers and their current appointments</p>
        </div>
      </div>

      <div className="card">
        {ministers.length === 0 ? (
          <div className="empty-state">
            <FiUser />
            <h3>No ministers</h3>
            <p>Ministers and their appointments will appear here</p>
          </div>
        ) : (
          <>
            <div className="table-container">
              <table>
                <thead>
                  <tr>
                    <th>Minister</th>
                    <th>Contact</th>
                    <th>Category</th>
                    <th>Society</th>
                    <th>Circuit</th>
                  </tr>
                </thead>
                <tbody>
                  {currentItems.map((m, idx) => (
                    <tr key={idx}>
                      <td><strong>{m.first_name} {m.surname}</strong></td>
                      <td>
                        <div style={{ fontSize: 12 }}>
                          {m.cellphone && <div>{m.cellphone}</div>}
                          {m.email && <div style={{ color: 'var(--text-secondary)' }}>{m.email}</div>}
                        </div>
                      </td>
                      <td><span className="badge badge-primary">{m.category_name}</span></td>
                      <td>{m.society_name}</td>
                      <td>{m.circuit_name}</td>
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
    </div>
  );
}
