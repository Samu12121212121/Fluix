import type { Emergency } from '../types';
import { EMERGENCY_LABELS, PRIORITY_LABELS, PRIORITY_COLORS } from '../types';

function elapsed(ts: number): string {
  const s = Math.round((Date.now() - ts) / 1000);
  if (s < 60) return `${s}s`;
  if (s < 3600) return `${Math.floor(s / 60)}m ${s % 60}s`;
  return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;
}

interface Props {
  emergencies: Emergency[];
  selectedEmergencyId: string | null;
  onSelect: (id: string) => void;
  onDispatch: (id: string) => void;
}

export default function EmergencyPanel({ emergencies, selectedEmergencyId, onSelect, onDispatch }: Props) {
  const active = emergencies.filter(e => e.state !== 'resolved');
  const resolved = emergencies.filter(e => e.state === 'resolved');

  return (
    <div className="panel" style={{ width: '288px', flexShrink: 0, borderLeft: '1px solid var(--border)', flex: '0 0 288px', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div className="panel-title">🚨 Emergencias activas ({active.length})</div>
      <div className="panel-scroll" style={{ maxHeight: '55%' }}>
        {active.length === 0 && (
          <div className="empty-state">
            <div className="empty-state-icon">✅</div>
            <div>Sin emergencias activas</div>
          </div>
        )}
        {active.map(emg => {
          const color = PRIORITY_COLORS[emg.priority];
          const sel = emg.id === selectedEmergencyId;
          return (
            <div
              key={emg.id}
              className={`emg-card ${sel ? 'emg-card--selected' : ''}`}
              onClick={() => onSelect(emg.id)}
            >
              <div className="emg-header">
                <div className={`emg-priority-dot emg-priority-dot--${emg.priority}`} />
                <div className="emg-title">{emg.type} · {EMERGENCY_LABELS[emg.type].split('—')[0].trim()}</div>
                <span className="emg-priority-badge" style={{ background: `${color}1a`, color }}>
                  {PRIORITY_LABELS[emg.priority]}
                </span>
              </div>
              <div className="emg-info">
                <div className="emg-info-row">
                  <span>📍</span>
                  <span style={{ fontWeight: 500 }}>{emg.address}</span>
                </div>
                <div className="emg-info-row">
                  <span>👥</span>
                  <span>{emg.patients} paciente{emg.patients > 1 ? 's' : ''}</span>
                </div>
                {sel && emg.description && (
                  <div style={{ fontSize: '11px', color: 'var(--text-sub)', marginTop: '4px', lineHeight: '1.4', fontStyle: 'italic' }}>
                    {emg.description}
                  </div>
                )}
              </div>
              <div className="emg-footer">
                {emg.assignedAmbulanceId ? (
                  <span className="emg-amb-badge">🚑 {emg.assignedAmbulanceId}</span>
                ) : (
                  <button
                    className="emg-dispatch-btn"
                    onClick={e => { e.stopPropagation(); onDispatch(emg.id); }}
                  >
                    DESPACHAR →
                  </button>
                )}
                <span className="emg-elapsed">⏱ {elapsed(emg.createdAt)}</span>
              </div>
              {emg.state === 'assigned' && (
                <div style={{ marginTop: '5px', fontSize: '10px', color: 'var(--blue)', fontWeight: 600 }}>
                  🔵 En desplazamiento...
                </div>
              )}
              {emg.state === 'active' && (
                <div style={{ marginTop: '5px', fontSize: '10px', color: 'var(--amber)', fontWeight: 600 }}>
                  🟡 Atendiendo emergencia
                </div>
              )}
            </div>
          );
        })}

        {resolved.length > 0 && (
          <>
            <div className="panel-title" style={{ marginTop: '0' }}>✅ Resueltas ({resolved.length})</div>
            {resolved.slice(0, 5).map(emg => (
              <div key={emg.id} className="emg-card emg-card--resolved">
                <div className="emg-header">
                  <div className="emg-priority-dot" style={{ background: 'var(--gray)' }} />
                  <div className="emg-title">{emg.type}</div>
                  <span style={{ fontSize: '10px', color: 'var(--green)', fontWeight: 700 }}>RESUELTA</span>
                </div>
                <div className="emg-info">
                  <div className="emg-info-row">📍 {emg.address}</div>
                </div>
              </div>
            ))}
          </>
        )}
      </div>
    </div>
  );
}
