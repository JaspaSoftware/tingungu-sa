import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, onSnapshot, query, orderBy, updateDoc, doc } from 'firebase/firestore';
import { FiMessageSquare, FiCheck } from 'react-icons/fi';
import { format } from 'date-fns';

const STATUS_COLORS = { open: 'badge-info', pending: 'badge-warning', resolved: 'badge-success', closed: 'badge-neutral' };

export default function TicketsPage() {
  const [tickets, setTickets] = useState([]);
  const [filter, setFilter] = useState('open');

  useEffect(() => {
    const q = query(collection(db, 'support_tickets'), orderBy('createdAt', 'desc'));
    return onSnapshot(q, snap => {
      setTickets(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
  }, []);

  const updateStatus = async (id, status) => {
    await updateDoc(doc(db, 'support_tickets', id), { status });
  };

  const filtered = tickets.filter(t => filter === 'all' || t.status === filter);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Support Tickets & Contact Messages</h1>
          <p>Messages submitted from the app and public website</p>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {['all', 'open', 'pending', 'resolved'].map(s => (
          <button
            key={s}
            className={`btn btn-sm ${filter === s ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setFilter(s)}
            style={{ textTransform: 'capitalize' }}
          >
            {s === 'all' ? 'All' : s} {s !== 'all' && `(${tickets.filter(t => t.status === s).length})`}
          </button>
        ))}
      </div>

      <div className="card">
        {filtered.length === 0 ? (
          <div className="empty-state">
            <FiMessageSquare />
            <h3>{filter === 'open' ? 'No open tickets' : 'No tickets found'}</h3>
            <p>Tickets submitted from the app will appear here</p>
          </div>
        ) : (
          <div className="table-container">
            <table>
              <thead>
                <tr><th>Subject</th><th>Message</th><th>User</th><th>Status</th><th>Date</th><th>Actions</th></tr>
              </thead>
              <tbody>
                {filtered.map(t => (
                  <tr key={t.id}>
                    <td><strong>{t.subject || 'No subject'}</strong></td>
                    <td style={{ maxWidth: 280 }} className="truncate">{t.message || '—'}</td>
                    <td style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                      {t.contactName ? `${t.contactName} · ` : ''}{t.userEmail || t.userId?.slice(0, 10) || '—'}
                    </td>
                    <td><span className={`badge ${STATUS_COLORS[t.status] || 'badge-neutral'}`} style={{ textTransform: 'capitalize' }}>{t.status || 'open'}</span></td>
                    <td style={{ fontSize: 12, color: 'var(--text-secondary)', whiteSpace: 'nowrap' }}>
                      {t.createdAt?.toDate ? format(t.createdAt.toDate(), 'dd MMM yyyy') : '—'}
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                        {t.status !== 'resolved' && (
                          <button className="btn btn-sm" style={{ background: '#d1fae5', color: '#065f46', border: 'none', cursor: 'pointer' }}
                            onClick={() => updateStatus(t.id, 'resolved')}>
                            <FiCheck size={13} /> Resolve
                          </button>
                        )}
                        {t.status === 'open' && (
                          <button className="btn btn-outline btn-sm" onClick={() => updateStatus(t.id, 'pending')}>
                            Pending
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
