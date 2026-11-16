import { useState } from 'react';
import type { DispatchRecommendation, Emergency } from '../types';
import { STATE_COLORS } from '../types';
import { INITIAL_AMBULANCES } from '../data';
import { formatDistance, formatEta } from '../dispatch';

interface Props {
  emergency: Emergency;
  recommendations: DispatchRecommendation[];
  rejectedIds: string[];
  onDispatch: (ambulanceId: string) => void;
  onClose: () => void;
}

export default function DispatchModal({ emergency, recommendations, rejectedIds, onDispatch, onClose }: Props) {
  const [selected, setSelected] = useState<string | null>(
    recommendations.find(r => r.available && !rejectedIds.includes(r.ambulanceId))?.ambulanceId ?? null
  );

  const priorityColors = { critical: '#7f1d1d', high: '#7c2d12', medium: '#713f12' };
  const headerBg = priorityColors[emergency.priority] ?? priorityColors.medium;

  const availableCount = recommendations.filter(r => r.available && !rejectedIds.includes(r.ambulanceId)).length;

  return (
    <div className="modal-backdrop dispatch-modal" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ width: '480px' }}>
        <div className="modal-header" style={{ background: headerBg }}>
          <div style={{ flex: 1 }}>
            <div className="modal-title">🚑 Asignación de Ambulancia</div>
            <div style={{ fontSize: '11px', color: 'rgba(255,255,255,0.65)', marginTop: '2px' }}>
              Algoritmo inteligente · {availableCount} unidad{availableCount !== 1 ? 'es' : ''} disponible{availableCount !== 1 ? 's' : ''}
            </div>
          </div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <div className="modal-body">
          {/* Emergency summary */}
          <div className="dispatch-emergency-info">
            <div className="dispatch-emergency-type">{emergency.type} · {emergency.priority.toUpperCase()}</div>
            <div className="dispatch-emergency-addr">📍 {emergency.address}</div>
            <div style={{ fontSize: '11px', color: 'var(--text-sub)', marginTop: '4px' }}>
              👥 {emergency.patients} paciente{emergency.patients > 1 ? 's' : ''} · {emergency.resources.join(' · ')}
            </div>
          </div>

          {/* Recommendations */}
          {recommendations.map((rec, idx) => {
            const isRejected = rejectedIds.includes(rec.ambulanceId);
            const amb = INITIAL_AMBULANCES.find(a => a.id === rec.ambulanceId);
            const isSel = selected === rec.ambulanceId;
            const isFirst = idx === 0 && rec.available && !isRejected;
            const isUnavail = !rec.available || isRejected;

            return (
              <div
                key={rec.ambulanceId}
                className={`rec-card ${isSel ? 'rec-card--selected' : ''} ${isUnavail ? 'rec-card--unavailable' : ''} ${isFirst ? 'rec-card--rank-1' : ''}`}
                onClick={() => !isUnavail && setSelected(rec.ambulanceId)}
              >
                <div className="rec-header">
                  <div className="rec-id">{rec.ambulanceId}</div>
                  <span className="rec-type-badge">{amb?.type ?? '?'}</span>
                  {!rec.typeMatch && emergency.type !== 'ACCIDENT' && emergency.type !== 'RESPIRATORY' && emergency.type !== 'GENERAL' && (
                    <span style={{ fontSize: '9px', color: 'var(--amber)', background: 'var(--amber-dim)', padding: '2px 6px', borderRadius: '4px', fontWeight: 700 }}>
                      ⚠ SVB para PCR/IAM
                    </span>
                  )}
                  <div className="rec-state" style={{ color: STATE_COLORS[amb?.state ?? 'offline'] }}>
                    {isRejected ? '⛔ Rechazó servicio' : rec.available ? '● Disponible' : `× ${rec.reason}`}
                  </div>
                </div>

                {rec.available && !isRejected && (
                  <div className="rec-metrics">
                    <div className="rec-metric">
                      <div className="rec-metric-val">{formatDistance(rec.distanceKm)}</div>
                      <div className="rec-metric-lbl">Distancia</div>
                    </div>
                    <div className="rec-metric">
                      <div className="rec-metric-val" style={{ color: rec.etaMinutes < 5 ? 'var(--green)' : rec.etaMinutes < 10 ? 'var(--amber)' : 'var(--red)' }}>
                        {formatEta(rec.etaMinutes)}
                      </div>
                      <div className="rec-metric-lbl">ETA estimado*</div>
                    </div>
                    <div className="rec-metric">
                      <div className="rec-metric-val">{Math.round(rec.distanceKm / 1.35 * 1000)} m</div>
                      <div className="rec-metric-lbl">Distancia directa</div>
                    </div>
                  </div>
                )}

                {rec.available && !isRejected && amb && (
                  <div className="rec-crew">{amb.crew.join(' · ')}</div>
                )}

                {(!rec.available || isRejected) && (
                  <div className="rec-unavail-reason">{isRejected ? 'Ha rechazado el servicio.' : rec.reason}</div>
                )}
              </div>
            );
          })}

          <div style={{ fontSize: '10px', color: 'var(--text-sub)', marginTop: '8px', fontStyle: 'italic' }}>
            * ETA calculado con factor de ruta urbana ×1.35 · 50-60 km/h con prioridad
          </div>
        </div>

        <div className="modal-footer">
          <button className="btn btn--ghost" onClick={onClose}>Cancelar</button>
          <button
            className={`btn btn--pink ${!selected ? 'btn--disabled' : ''}`}
            onClick={() => selected && onDispatch(selected)}
            disabled={!selected}
          >
            🚨 ASIGNAR EMERGENCIA
          </button>
        </div>
      </div>
    </div>
  );
}
