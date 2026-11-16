import type { Ambulance, Emergency } from '../types';
import { STATE_COLORS, STATE_LABELS } from '../types';
import { haversineKm } from '../simulation';
import { formatDistance, formatEta } from '../dispatch';

function ElapsedGPS({ ts }: { ts: number }) {
  const sec = Math.round((Date.now() - ts) / 1000);
  if (sec < 10) return <span style={{ color: 'var(--green)' }}>hace {sec}s</span>;
  if (sec < 60) return <span style={{ color: 'var(--amber)' }}>hace {sec}s</span>;
  return <span style={{ color: 'var(--red)' }}>hace {Math.round(sec / 60)}m ⚠</span>;
}

interface Props {
  ambulances: Ambulance[];
  selectedAmbulanceId: string | null;
  selectedEmergency: Emergency | null;
  onSelect: (id: string) => void;
  onToggleOffline: (id: string) => void;
}

export default function AmbulancePanel({ ambulances, selectedAmbulanceId, selectedEmergency, onSelect, onToggleOffline }: Props) {
  return (
    <div className="panel panel-left">
      <div className="panel-title">🚑 Vehículos ({ambulances.length})</div>
      <div className="panel-scroll">
        {ambulances.map(amb => {
          const color = STATE_COLORS[amb.state];
          const sel = amb.id === selectedAmbulanceId;
          const isPulsing = amb.state === 'dispatched' || amb.state === 'attending';

          let distKm: number | null = null;
          let etaMin: number | null = null;
          if (selectedEmergency && amb.state === 'available') {
            distKm = haversineKm(amb.lat, amb.lng, selectedEmergency.lat, selectedEmergency.lng) * 1.35;
            etaMin = (distKm / 50) * 60;
          }

          return (
            <div
              key={amb.id}
              className={`amb-card ${sel ? 'amb-card--selected' : ''} ${amb.state === 'offline' ? 'amb-card--offline' : ''}`}
              onClick={() => onSelect(amb.id)}
            >
              <div className="amb-card-header">
                <div
                  className={`amb-dot${isPulsing ? ' amb-dot--pulse' : ''}`}
                  style={{ background: color }}
                />
                <span className="amb-id">{amb.id}</span>
                <span className="amb-type">{amb.type}</span>
                <span className="amb-state-badge" style={{ background: `${color}1a`, color }}>
                  {STATE_LABELS[amb.state]}
                </span>
              </div>

              <div className="amb-info">
                <div className="amb-info-row">
                  <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor">
                    <circle cx="5" cy="5" r="4" fill="none" stroke="currentColor" strokeWidth="1.5"/>
                    <path d="M5 2.5v2.5l1.5 1.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
                  </svg>
                  <span>{amb.speed} km/h · {amb.zone}</span>
                </div>
                <div className="amb-info-row">
                  <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor">
                    <path d="M5 1a3 3 0 0 1 3 3c0 2-3 5-3 5S2 6 2 4a3 3 0 0 1 3-3z" fill="none" stroke="currentColor" strokeWidth="1.5"/>
                    <circle cx="5" cy="4" r="1" fill="currentColor"/>
                  </svg>
                  <span style={{ fontFamily: 'JetBrains Mono', fontSize: '10px' }}>
                    {amb.lat.toFixed(4)}, {amb.lng.toFixed(4)}
                  </span>
                </div>
                <div className="amb-info-row">
                  <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor">
                    <rect x="1" y="1" width="8" height="8" rx="2" fill="none" stroke="currentColor" strokeWidth="1.5"/>
                    <path d="M4 4l2 1-2 1" fill="currentColor"/>
                  </svg>
                  <span>GPS: <ElapsedGPS ts={amb.lastGpsUpdate} /></span>
                </div>
                {amb.assignedEmergencyId && (
                  <div className="amb-info-row" style={{ color: 'var(--blue)', fontWeight: 600 }}>
                    ⚡ {amb.assignedEmergencyId}
                  </div>
                )}
              </div>

              {distKm !== null && etaMin !== null && selectedEmergency && (
                <div className="amb-eta">
                  <div className="amb-eta-item">
                    <div className="amb-eta-val">{formatDistance(distKm)}</div>
                    <div className="amb-eta-lbl">Distancia</div>
                  </div>
                  <div className="amb-eta-item">
                    <div className="amb-eta-val">{formatEta(etaMin)}</div>
                    <div className="amb-eta-lbl">ETA</div>
                  </div>
                </div>
              )}

              {sel && (
                <div style={{ marginTop: '8px', display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                  {amb.crew.map(c => (
                    <span key={c} style={{ fontSize: '10px', background: 'var(--surface-2)', border: '1px solid var(--border)', padding: '2px 6px', borderRadius: '10px', color: 'var(--text-sub)' }}>
                      {c}
                    </span>
                  ))}
                </div>
              )}

              {sel && (
                <div style={{ marginTop: '8px' }}>
                  <button
                    className={`ctrl-btn ${amb.state === 'offline' ? 'ctrl-btn--teal' : 'ctrl-btn--red'}`}
                    style={{ fontSize: '10px', padding: '3px 8px' }}
                    onClick={e => { e.stopPropagation(); onToggleOffline(amb.id); }}
                  >
                    {amb.state === 'offline' ? '▶ Poner operativa' : '⏸ Fuera de servicio'}
                  </button>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
