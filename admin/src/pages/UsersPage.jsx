import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, onSnapshot, doc, updateDoc } from 'firebase/firestore';
import { FiUsers } from 'react-icons/fi';
import { format } from 'date-fns';

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
          <button className="btn btn-outline" onClick={onClose}>Close</button>
          <button className="btn btn-primary" onClick={onSave} disabled={loading}>
            {loading ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;
  
  const [selectedUser, setSelectedUser] = useState(null);
  const [savingProfile, setSavingProfile] = useState(false);
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');

  useEffect(() => {
    return onSnapshot(collection(db, 'users'), snap => {
      setUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
  }, []);

  const filtered = users.filter(u =>
    (u.displayname || u.email || '').toLowerCase().includes(search.toLowerCase())
  );

  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  const activePage = Math.min(currentPage, Math.max(totalPages, 1));
  const indexOfLastItem = activePage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentUsers = filtered.slice(indexOfFirstItem, indexOfLastItem);

  const initials = (u) => {
    const name = u.displayname || u.email || '?';
    return name.slice(0, 2).toUpperCase();
  };

  const openProfile = (u) => {
    setSelectedUser(u);
    setFirstName(u.firstname || u.first_name || '');
    setLastName(u.lastname || u.last_name || '');
  };

  const saveProfile = async () => {
    if (!selectedUser) return;
    setSavingProfile(true);
    try {
      const displayName = `${firstName.trim()} ${lastName.trim()}`.trim();
      await updateDoc(doc(db, 'users', selectedUser.id), {
        firstname: firstName.trim(),
        lastname: lastName.trim(),
        displayname: displayName || selectedUser.displayname || ''
      });
      setSelectedUser(prev => prev
        ? { ...prev, firstname: firstName.trim(), lastname: lastName.trim(), displayname: displayName || prev.displayname }
        : null);
    } catch (err) {
      console.error("Error updating user profile:", err);
      alert("Failed to update user profile");
    } finally {
      setSavingProfile(false);
    }
  };

  const roleBadgeColor = (role = '') => {
    const rLower = role.toLowerCase();
    if (rLower === 'superadmin') return 'badge-danger';
    if (rLower === 'admin') return 'badge-info';
    if (rLower === 'pastor') return 'badge-warning';
    return 'badge-neutral';
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Users</h1>
          <p>{users.length} registered members</p>
        </div>
        <div className="search-bar">
          <FiUsers size={16} />
          <input
            placeholder="Search by name or email..."
            value={search}
            onChange={e => {
              setSearch(e.target.value);
              setCurrentPage(1);
            }}
          />
        </div>
      </div>

      <div className="card">
        {filtered.length === 0 ? (
          <div className="empty-state">
            <FiUsers />
            <h3>No users found</h3>
            <p>{search ? 'Try a different search term' : 'No users registered yet'}</p>
          </div>
        ) : (
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Member</th>
                  <th>Email</th>
                  <th>Role label</th>
                  <th>Society</th>
                  <th>Wallet Balance</th>
                  <th>Status</th>
                  <th>Joined</th>
                </tr>
              </thead>
              <tbody>
                {currentUsers.map(u => (
                  <tr key={u.id} onClick={() => openProfile(u)} style={{ cursor: 'pointer' }}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <div className="avatar">{initials(u)}</div>
                        <div>
                          <div style={{ fontWeight: 600, fontSize: 14 }}>{u.displayname || 'â€”'}</div>
                          <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{u.id.slice(0, 8)}...</div>
                        </div>
                      </div>
                    </td>
                    <td>{u.email || 'â€”'}</td>
                    <td>
                      <span className={`badge ${roleBadgeColor(u.role)}`} style={{ textTransform: 'capitalize' }}>
                        {u.role || 'member'}
                      </span>
                    </td>
                    <td>{u.society || <span style={{ color: 'var(--text-secondary)' }}>Not set</span>}</td>
                    <td>
                      <span style={{ fontWeight: 600, color: 'var(--maroon)' }}>
                        R {(u.wallet_balance || 0).toFixed(2)}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                        <span className={`badge ${u.profile_completed ? 'badge-success' : 'badge-warning'}`}>
                          {u.profile_completed ? 'Complete' : 'Incomplete'}
                        </span>
                        {u.suspended && (
                          <span className="badge badge-danger" style={{ textAlign: 'center' }}>
                            Suspended
                          </span>
                        )}
                      </div>
                    </td>
                    <td style={{ color: 'var(--text-secondary)', fontSize: 13 }}>
                      {u.createdAt?.toDate ? format(u.createdAt.toDate(), 'dd MMM yyyy') : 'â€”'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {totalPages > 1 && (
              <div className="pagination" style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 12, padding: '16px 24px', borderTop: '1px solid var(--border)' }}>
                <button
                  className="btn btn-outline btn-sm"
                  onClick={() => setCurrentPage(Math.max(activePage - 1, 1))}
                  disabled={activePage === 1}
                >
                  Previous
                </button>
                <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>
                  Page {activePage} of {totalPages}
                </span>
                <button
                  className="btn btn-outline btn-sm"
                  onClick={() => setCurrentPage(Math.min(activePage + 1, totalPages))}
                  disabled={activePage === totalPages}
                >
                  Next
                </button>
              </div>
            )}
          </div>
        )}
      </div>

      {selectedUser && (
        <Modal title="Member Profile" onClose={() => setSelectedUser(null)} onSave={saveProfile} loading={savingProfile}>
          <div style={{ display: 'flex', gap: 16, alignItems: 'center', marginBottom: 20 }}>
            <div className="avatar" style={{ width: 56, height: 56, borderRadius: '50%', fontSize: 20, display: 'flex', alignItems: 'center', justifyContent: 'center', backgroundColor: 'var(--border)', color: 'var(--text-main)', fontWeight: 'bold' }}>
              {initials(selectedUser)}
            </div>
            <div>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <h4 style={{ margin: 0, fontSize: 16, fontWeight: 700 }}>{selectedUser.displayname || 'â€”'}</h4>
                {selectedUser.suspended && <span className="badge badge-danger">Suspended</span>}
              </div>
            </div>
          </div>

          <div className="form-row" style={{ marginBottom: 16 }}>
            <div className="form-group">
              <label className="form-label" style={{ fontWeight: 600 }}>First Name</label>
              <input className="form-control" placeholder="e.g. John" value={firstName} onChange={e => setFirstName(e.target.value)} />
            </div>
            <div className="form-group">
              <label className="form-label" style={{ fontWeight: 600 }}>Last Name</label>
              <input className="form-control" placeholder="e.g. Doe" value={lastName} onChange={e => setLastName(e.target.value)} />
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px 12px', marginBottom: 24 }}>
            <div className="info-group">
              <label style={{ fontSize: 11, color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Email Address</label>
              <div style={{ fontSize: 14, fontWeight: 500, marginTop: 4, wordBreak: 'break-all' }}>{selectedUser.email || 'â€”'}</div>
            </div>
            <div className="info-group">
              <label style={{ fontSize: 11, color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Society</label>
              <div style={{ fontSize: 14, fontWeight: 500, marginTop: 4 }}>{selectedUser.society || 'Not set'}</div>
            </div>
            <div className="info-group">
              <label style={{ fontSize: 11, color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Wallet Balance</label>
              <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--maroon)', marginTop: 4 }}>R {(selectedUser.wallet_balance || 0).toFixed(2)}</div>
            </div>
            <div className="info-group">
              <label style={{ fontSize: 11, color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Profile Status</label>
              <div style={{ marginTop: 4 }}>
                <span className={`badge ${selectedUser.profile_completed ? 'badge-success' : 'badge-warning'}`}>
                  {selectedUser.profile_completed ? 'Complete' : 'Incomplete'}
                </span>
              </div>
            </div>
            <div className="info-group">
              <label style={{ fontSize: 11, color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Date Joined</label>
              <div style={{ fontSize: 14, fontWeight: 500, marginTop: 4 }}>
                {selectedUser.createdAt?.toDate ? format(selectedUser.createdAt.toDate(), 'dd MMM yyyy HH:mm') : 'â€”'}
              </div>
            </div>
            <div className="info-group">
              <label style={{ fontSize: 11, color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Cellphone</label>
              <div style={{ fontSize: 14, fontWeight: 500, marginTop: 4 }}>{selectedUser.cellphone || 'â€”'}</div>
            </div>
          </div>

          <p style={{ marginTop: 20, color: 'var(--text-secondary)' }}>
            Account roles, suspension, and deletion are managed through trusted
            Firebase administration, not by editing a profile document.
          </p>
        </Modal>
      )}
    </div>
  );
}
