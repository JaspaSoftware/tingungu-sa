import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, onSnapshot, query, orderBy } from 'firebase/firestore';
import { FiUsers, FiDollarSign, FiBell, FiVideo, FiTrendingUp, FiHeart, FiShoppingBag, FiMessageSquare } from 'react-icons/fi';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend } from 'recharts';
import { API_BASE_URL } from '../config';

const COLORS = ['#3B0D11', '#FB8B24', '#10b981', '#3b82f6', '#8b5cf6'];

const mockRevenueData = [
  { month: 'Jan', giving: 4200 },
  { month: 'Feb', giving: 5100 },
  { month: 'Mar', giving: 3800 },
  { month: 'Apr', giving: 6200 },
  { month: 'May', opening: 5400 },
  { month: 'Jun', giving: 7100 },
];

export default function Dashboard() {
  const [userCount, setUserCount] = useState(null);
  const [noticeCount, setNoticeCount] = useState(null);
  const [mediaCount, setMediaCount] = useState(null);
  const [sqlStats, setSqlStats] = useState({ districts: 0, circuits: 0, societies: 0, ministers: 0 });
  const [givingDist, setGivingDist] = useState([]);
  const [revenueData, setRevenueData] = useState(mockRevenueData);

  useEffect(() => {
    const unsubs = [];

    // Firestore Stats
    unsubs.push(onSnapshot(collection(db, 'users'), snap => setUserCount(snap.size)));
    unsubs.push(onSnapshot(collection(db, 'notices'), snap => setNoticeCount(snap.size)));
    unsubs.push(onSnapshot(collection(db, 'media'), snap => setMediaCount(snap.size)));

    // MySQL Stats
    const fetchSqlStats = async () => {
      try {
        const res = await fetch(`${API_BASE_URL}/stats`, { cache: 'no-cache' });
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        const data = await res.json();
        setSqlStats(data);
      } catch (err) {
        console.error('Error fetching SQL stats:', err);
      }
    };
    fetchSqlStats();
    const interval = setInterval(fetchSqlStats, 5000);

    // Helper to generate last 6 months slots
    const getLast6Months = () => {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const result = [];
      const today = new Date();
      for (let i = 5; i >= 0; i--) {
        const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
        result.push({
          month: months[d.getMonth()],
          year: d.getFullYear(),
          monthIndex: d.getMonth(),
          giving: 0
        });
      }
      return result;
    };

    const processTransactions = (txList) => {
      const revSlots = getLast6Months();
      let hasRealRevenue = false;
      const givingMap = {};
      let hasRealGiving = false;

      txList.forEach(t => {
        const txDate = t.createdAt || t.date || t.timestamp;
        if (!txDate) return;

        const dateObj = txDate.toDate ? txDate.toDate() : new Date(txDate);
        if (isNaN(dateObj.getTime())) return;

        const amount = Number(t.amount) || 0;
        const typeLower = (t.type || '').toLowerCase();

        const mIdx = dateObj.getMonth();
        const yVal = dateObj.getFullYear();
        const slot = revSlots.find(s => s.monthIndex === mIdx && s.year === yVal);

        if (typeLower.includes('giving')) {
          if (slot) {
            slot.giving += amount;
            hasRealRevenue = true;
          }
          let optionName = 'Other';
          const match = (t.type || '').match(/Giving:\s*([^(:]+)/i);
          if (match && match[1]) {
            optionName = match[1].trim();
          } else {
            optionName = t.description || (t.type || '').replace(/giving:?/i, '').trim() || 'Giving';
          }
          givingMap[optionName] = (givingMap[optionName] || 0) + amount;
          hasRealGiving = true;
        }
      });

      if (hasRealRevenue) {
        setRevenueData(revSlots);
      } else {
        setRevenueData(mockRevenueData);
      }

      if (hasRealGiving) {
        const dist = Object.entries(givingMap).map(([name, value]) => ({ name, value }));
        setGivingDist(dist);
      } else {
        // Fallback: fetch giving options and generate random values
        const qOptions = query(collection(db, 'giving_options'));
        const unsubOptions = onSnapshot(qOptions, snap => {
          if (snap.size > 0) {
            setGivingDist(snap.docs.map(d => ({ name: d.data().name || 'Option', value: Math.floor(Math.random() * 3000) + 500 })));
          } else {
            setGivingDist([
              { name: 'Tithes', value: 2450 },
              { name: 'Offerings', value: 1200 },
              { name: 'Building Fund', value: 850 }
            ]);
          }
        });
        unsubs.push(unsubOptions);
      }
    };

    // Listen to transactions
    let txUnsub;
    try {
      const q = query(collectionGroup(db, 'transactions'));
      txUnsub = onSnapshot(q, snap => {
        const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
        processTransactions(list);
      }, err => {
        console.warn("collectionGroup transactions subscription failed, falling back to top-level collection...", err);
        const q2 = query(collection(db, 'transactions'));
        const unsub2 = onSnapshot(q2, snap => {
          const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
          processTransactions(list);
        });
        unsubs.push(unsub2);
      });
      unsubs.push(txUnsub);
    } catch (err) {
      console.warn("collectionGroup query failed, falling back...", err);
      const unsub2 = onSnapshot(collection(db, 'transactions'), snap => {
        const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
        processTransactions(list);
      });
      unsubs.push(unsub2);
    }

    return () => {
      unsubs.forEach(u => u());
      clearInterval(interval);
    };
  }, []);

  const stats = [
    {
      label: 'Total Users', value: userCount ?? '—',
      icon: FiUsers, color: '#3B0D11', bg: 'rgba(59,13,17,0.08)',
    },
    {
      label: 'Societies', value: sqlStats.societies,
      icon: FiShoppingBag, color: '#10b981', bg: '#d1fae5',
    },
    {
      label: 'Circuits', value: sqlStats.circuits,
      icon: FiBell, color: '#f59e0b', bg: '#fef3c7',
    },
    {
      label: 'Districts', value: sqlStats.districts,
      icon: FiVideo, color: '#3b82f6', bg: '#dbeafe',
    },
    {
      label: 'Active Notices', value: noticeCount ?? '—',
      icon: FiBell, color: '#f59e0b', bg: '#fef3c7',
    },
    {
      label: 'Media Videos', value: mediaCount ?? '—',
      icon: FiVideo, color: '#3b82f6', bg: '#dbeafe',
    },

    {
      label: 'Ministers', value: sqlStats.ministers,
      icon: FiUsers, color: '#FB8B24', bg: 'rgba(251,139,36,0.1)',
    },
  ];

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Dashboard</h1>
          <p>Welcome back — here's what's happening with Tingungu</p>
        </div>
      </div>

      {/* Stats */}
      <div className="stats-grid">
        {stats.map(({ label, value, icon: Icon, color, bg }) => (
          <div className="stat-card" key={label}>
            <div className="stat-icon" style={{ background: bg }}>
              <Icon style={{ color, width: 22, height: 22 }} />
            </div>
            <div className="stat-info">
              <div className="stat-value">{value}</div>
              <div className="stat-label">{label}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Charts */}
      <div className="chart-grid">
        <div className="card">
          <div className="card-header">
            <h3>Revenue Overview</h3>
            <span className="badge badge-success">↑ 14% this month</span>
          </div>
          <div className="card-body" style={{ paddingTop: 16 }}>
            <ResponsiveContainer width="100%" height={220}>
              <AreaChart data={revenueData}>
                <defs>
                  <linearGradient id="gGiving" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3B0D11" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#3B0D11" stopOpacity={0} />
                  </linearGradient>

                </defs>
                <XAxis dataKey="month" tick={{ fontSize: 12 }} />
                <YAxis tick={{ fontSize: 12 }} tickFormatter={v => `R${v / 1000}k`} />
                <Tooltip formatter={(v) => [`R ${v.toLocaleString()}`, 'Giving']} />
                <Area type="monotone" dataKey="giving" stroke="#3B0D11" fill="url(#gGiving)" strokeWidth={2} name="giving" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="card">
          <div className="card-header"><h3>Giving Distribution</h3></div>
          <div className="card-body" style={{ paddingTop: 8 }}>
            {givingDist.length > 0 ? (
              <ResponsiveContainer width="100%" height={220}>
                <PieChart>
                  <Pie data={givingDist} cx="50%" cy="50%" innerRadius={55} outerRadius={85}
                    dataKey="value" nameKey="name" paddingAngle={3}>
                    {givingDist.map((_, i) => (
                      <Cell key={i} fill={COLORS[i % COLORS.length]} />
                    ))}
                  </Pie>
                  <Legend iconSize={10} wrapperStyle={{ fontSize: 11 }} />
                  <Tooltip formatter={v => `R ${v.toLocaleString()}`} />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="empty-state" style={{ padding: '40px 0' }}>
                <p>No giving data yet — seed giving options first.</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Quick actions */}
      <div className="card">
        <div className="card-header"><h3>Quick Actions</h3></div>
        <div className="card-body">
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
            {[
              { label: 'Send Notice', color: 'btn-primary' },
              { label: 'Add Video', color: 'btn-orange' },
              { label: 'Add Giving Option', color: 'btn-outline' },
              { label: 'Create Event', color: 'btn-outline' },
              { label: 'View Tickets', color: 'btn-outline' },
            ].map(({ label, color }) => (
              <button key={label} className={`btn ${color}`}>{label}</button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
