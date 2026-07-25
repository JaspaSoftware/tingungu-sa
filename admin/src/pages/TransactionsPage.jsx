import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collectionGroup, collection, onSnapshot, query, orderBy } from 'firebase/firestore';
import { FiDollarSign } from 'react-icons/fi';
import { format } from 'date-fns';

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState([]);
  const [filter, setFilter] = useState('all');
  const [search, setSearch] = useState('');

  useEffect(() => {
    const unsubs = [];

    const processDocs = (snap) => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      list.sort((a, b) => {
        const da = a.createdAt || a.date || a.timestamp;
        const db = b.createdAt || b.date || b.timestamp;
        const tA = da?.toDate ? da.toDate().getTime() : (da ? new Date(da).getTime() : 0);
        const tB = db?.toDate ? db.toDate().getTime() : (db ? new Date(db).getTime() : 0);
        return tB - tA;
      });
      setTransactions(list);
    };

    try {
      const q = query(collectionGroup(db, 'transactions'));
      const unsub = onSnapshot(q, processDocs, err => {
        console.warn("collectionGroup transactions subscription failed, falling back to top-level collection...", err);
        const q2 = query(collection(db, 'transactions'));
        const unsub2 = onSnapshot(q2, processDocs);
        unsubs.push(unsub2);
      });
      unsubs.push(unsub);
    } catch (err) {
      console.warn("collectionGroup query creation failed, falling back...", err);
      unsubs.push(onSnapshot(collection(db, 'transactions'), processDocs));
    }

    return () => unsubs.forEach(u => u());
  }, []);

  const types = ['all', 'giving', 'topup', 'airtime'];

  const filtered = transactions.filter(t => {
    const typeLower = (t.type || '').toLowerCase();
    let matchType = false;
    if (filter === 'all') {
      matchType = true;
    } else if (filter === 'topup') {
      matchType = typeLower.includes('topup') || typeLower.includes('top-up');
    } else {
      matchType = typeLower.includes(filter);
    }
    const matchSearch = (t.description || t.type || '').toLowerCase().includes(search.toLowerCase());
    return matchType && matchSearch;
  });

  const total = filtered.reduce((sum, t) => sum + (Number(t.amount) || 0), 0);

  const typeColor = (type = '') => {
    const tLower = type.toLowerCase();
    if (tLower.includes('giving')) return 'badge-danger';
    if (tLower.includes('topup') || tLower.includes('top-up')) return 'badge-success';
    if (tLower.includes('airtime')) return 'badge-warning';
    return 'badge-neutral';
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Transactions</h1>
          <p>{transactions.length} total transactions</p>
        </div>
        <div className="search-bar">
          <FiDollarSign size={16} />
          <input placeholder="Search transactions..." value={search} onChange={e => setSearch(e.target.value)} />
        </div>
      </div>

      {/* Filters */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
        {types.map(t => (
          <button
            key={t}
            className={`btn btn-sm ${filter === t ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setFilter(t)}
            style={{ textTransform: 'capitalize' }}
          >
            {t === 'all' ? 'All Types' : t}
          </button>
        ))}
        <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>Showing {filtered.length} records</span>
          <span style={{ fontWeight: 700, color: 'var(--maroon)' }}>Total: R {total.toFixed(2)}</span>
        </div>
      </div>

      <div className="card">
        {filtered.length === 0 ? (
          <div className="empty-state">
            <FiDollarSign />
            <h3>No transactions found</h3>
            <p>Transactions will appear here as users make payments</p>
          </div>
        ) : (
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Description</th>
                  <th>Type</th>
                  <th>Amount</th>
                  <th>User ID</th>
                  <th>Date</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(t => (
                  <tr key={t.id}>
                    <td><strong>{t.description || t.type || '—'}</strong></td>
                    <td><span className={`badge ${typeColor(t.type)}`} style={{ textTransform: 'capitalize' }}>{t.type || 'Unknown'}</span></td>
                    <td style={{ fontWeight: 700, color: (t.type || '').toLowerCase().includes('topup') ? 'var(--success)' : 'var(--maroon)' }}>
                      {(t.type || '').toLowerCase().includes('topup') ? '+' : '-'}R {(Math.abs(Number(t.amount)) || 0).toFixed(2)}
                    </td>
                    <td style={{ fontFamily: 'monospace', fontSize: 12, color: 'var(--text-secondary)' }}>
                      {t.userId?.slice(0, 12) || '—'}...
                    </td>
                    <td style={{ fontSize: 13, color: 'var(--text-secondary)', whiteSpace: 'nowrap' }}>
                      {(() => {
                        const txDate = t.createdAt || t.date || t.timestamp;
                        if (!txDate) return '—';
                        const dateObj = txDate.toDate ? txDate.toDate() : new Date(txDate);
                        return isNaN(dateObj.getTime()) ? '—' : format(dateObj, 'dd MMM yyyy HH:mm');
                      })()}
                    </td>
                    <td><span className="badge badge-success">Completed</span></td>
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
