import { useState, useEffect } from 'react';
import type { Emergency, EmergencyType, Priority } from '../types';
import { EMERGENCY_LABELS, PRIORITY_LABELS } from '../types';

const RESOURCES = ['DEA', 'O2', 'Monitor ECG', 'Monitor cardíaco', 'Collarín', 'Tabla espinal',
  'Férulas', 'Nitratos', 'Acceso venoso', 'Incubadora', 'Bomba perfusión'];

const QUICK_TYPES: Array<{ type: EmergencyType; priority: Priority; desc: string }> = [
  { type: 'PCR', priority: 'critical', desc: 'Parada cardiorrespiratoria. Testigos realizando RCP.' },
  { type: 'IAM', priority: 'critical', desc: 'Dolor torácico irradiado, sudoración, náuseas.' },
  { type: 'TCE', priority: 'high', desc: 'Traumatismo craneal tras impacto. Pérdida de conocimiento breve.' },
  { type: 'ACCIDENT', priority: 'high', desc: 'Colisión en vía urbana. Heridos moderados.' },
  { type: 'RESPIRATORY', priority: 'medium', desc: 'Dificultad respiratoria severa, saturación baja.' },
  { type: 'GENERAL', priority: 'medium', desc: 'Urgencia médica inespecífica.' },
];

interface Props {
  pickedCoords: { lat: number; lng: number } | null;
  onPickCoords: () => void;
  onClose: () => void;
  onSubmit: (emg: Omit<Emergency, 'id' | 'createdAt' | 'state'>) => void;
}

export default function NewEmergencyModal({ pickedCoords, onPickCoords, onClose, onSubmit }: Props) {
  const [type, setType] = useState<EmergencyType>('GENERAL');
  const [priority, setPriority] = useState<Priority>('medium');
  const [address, setAddress] = useState('');
  const [patients, setPatients] = useState(1);
  const [description, setDescription] = useState('');
  const [resources, setResources] = useState<string[]>([]);

  useEffect(() => {
    const qt = QUICK_TYPES.find(q => q.type === type);
    if (qt && !description) {
      setPriority(qt.priority);
      setDescription(qt.desc);
    }
  }, [type]);

  const toggleResource = (r: string) =>
    setResources(prev => prev.includes(r) ? prev.filter(x => x !== r) : [...prev, r]);

  const handleSubmit = () => {
    const lat = pickedCoords?.lat ?? 40.6333;
    const lng = pickedCoords?.lng ?? -3.1667;
    const addr = address.trim() || (pickedCoords
      ? `${lat.toFixed(4)}, ${lng.toFixed(4)} · Guadalajara`
      : 'Ubicación seleccionada · Guadalajara');
    onSubmit({ type, priority, address: addr, lat, lng, patients, description, resources, assignedAmbulanceId: undefined });
  };

  return (
    <div className="modal-backdrop" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ width: '520px' }}>
        <div className="modal-header" style={{ background: '#7f1d1d' }}>
          <div className="modal-title">🚨 Nueva Emergencia</div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body" style={{ maxHeight: '70vh', overflowY: 'auto' }}>

          {/* Quick type selector */}
          <div className="form-row">
            <div className="form-label">Tipo de emergencia</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '6px' }}>
              {QUICK_TYPES.map(qt => (
                <div
                  key={qt.type}
                  onClick={() => setType(qt.type)}
                  style={{
                    padding: '8px 10px', borderRadius: '8px', cursor: 'pointer',
                    border: `2px solid ${type === qt.type ? '#EF4444' : 'var(--border)'}`,
                    background: type === qt.type ? 'var(--red-dim)' : 'var(--surface-2)',
                    fontSize: '12px', fontWeight: type === qt.type ? '700' : '400',
                    transition: 'all 0.15s',
                  }}
                >
                  <div style={{ fontWeight: 700, color: type === qt.type ? 'var(--red)' : 'var(--text)' }}>{qt.type}</div>
                  <div style={{ fontSize: '10px', color: 'var(--text-sub)', marginTop: '2px' }}>{EMERGENCY_LABELS[qt.type].split('—')[0].trim()}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Priority */}
          <div className="form-row">
            <div className="form-label">Prioridad</div>
            <div style={{ display: 'flex', gap: '8px' }}>
              {(['critical', 'high', 'medium'] as Priority[]).map(p => (
                <div
                  key={p}
                  onClick={() => setPriority(p)}
                  style={{
                    flex: 1, padding: '7px', textAlign: 'center', borderRadius: '8px',
                    cursor: 'pointer', fontSize: '12px', fontWeight: 700,
                    border: `2px solid ${priority === p ? (p === 'critical' ? 'var(--red)' : p === 'high' ? 'var(--orange)' : 'var(--yellow)') : 'var(--border)'}`,
                    background: priority === p ? (p === 'critical' ? 'var(--red-dim)' : p === 'high' ? 'var(--orange-dim)' : 'rgba(234,179,8,0.12)') : 'var(--surface-2)',
                    color: p === 'critical' ? 'var(--red)' : p === 'high' ? 'var(--orange)' : 'var(--yellow)',
                    transition: 'all 0.15s',
                  }}
                >
                  {p === 'critical' ? '🔴' : p === 'high' ? '🟠' : '🟡'} {PRIORITY_LABELS[p]}
                </div>
              ))}
            </div>
          </div>

          {/* Location */}
          <div className="form-row">
            <div className="form-label">Ubicación</div>
            <div style={{ display: 'flex', gap: '8px', marginBottom: '6px' }}>
              <input
                className="form-input"
                placeholder="Ej: Av. del Ejército, 15 · Guadalajara"
                value={address}
                onChange={e => setAddress(e.target.value)}
              />
            </div>
            <div
              className={`form-coords ${pickedCoords ? 'form-coords--picked' : ''}`}
              style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px' }}
              onClick={onPickCoords}
            >
              {pickedCoords
                ? `📍 ${pickedCoords.lat.toFixed(5)}, ${pickedCoords.lng.toFixed(5)} (seleccionado)`
                : '🗺 Haz clic aquí y luego en el mapa para seleccionar coordenadas'}
            </div>
          </div>

          {/* Patients + Description */}
          <div className="form-row-2 form-row">
            <div>
              <div className="form-label">Nº pacientes</div>
              <input
                className="form-input"
                type="number"
                min={1}
                max={20}
                value={patients}
                onChange={e => setPatients(Number(e.target.value))}
              />
            </div>
            <div>
              <div className="form-label">Recursos necesarios</div>
              <div className="resources-grid">
                {RESOURCES.map(r => (
                  <div key={r} className={`resource-chip ${resources.includes(r) ? 'resource-chip--selected' : ''}`} onClick={() => toggleResource(r)}>
                    {r}
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="form-row">
            <div className="form-label">Descripción</div>
            <textarea
              className="form-textarea"
              value={description}
              onChange={e => setDescription(e.target.value)}
              placeholder="Descripción del incidente..."
            />
          </div>
        </div>

        <div className="modal-footer">
          <button className="btn btn--ghost" onClick={onClose}>Cancelar</button>
          <button className="btn btn--red" onClick={handleSubmit}>
            🚨 Crear Emergencia
          </button>
        </div>
      </div>
    </div>
  );
}
