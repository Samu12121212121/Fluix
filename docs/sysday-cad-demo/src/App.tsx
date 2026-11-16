import { useReducer, useEffect, useRef, useCallback, useState } from 'react';
import L from 'leaflet';
import type { AppState, AppAction, Emergency, HistoryEntry } from './types';
import { INITIAL_AMBULANCES, SAMPLE_EMERGENCIES, RANDOM_LOCATIONS } from './data';
import { tickAmbulance, createDispatchRoute } from './simulation';
import { calculateRecommendations } from './dispatch';
import MapView from './components/MapView';
import AmbulancePanel from './components/AmbulancePanel';
import EmergencyPanel from './components/EmergencyPanel';
import NewEmergencyModal from './components/NewEmergencyModal';
import DispatchModal from './components/DispatchModal';
import HistoryLog from './components/HistoryLog';

let emgCounter = SAMPLE_EMERGENCIES.length + 1;
let histCounter = 1;

function makeHistory(message: string, category: HistoryEntry['category']): HistoryEntry {
  return { id: `h${histCounter++}`, timestamp: Date.now(), message, category };
}

const INITIAL_STATE: AppState = {
  ambulances: INITIAL_AMBULANCES,
  emergencies: SAMPLE_EMERGENCIES,
  history: [
    makeHistory('Sistema CAD iniciado — Sysday Emergencias Guadalajara', 'system'),
    makeHistory('AMB-05 sin conexión GPS (última señal hace 9 min)', 'system'),
    makeHistory('3 emergencias pendientes de asignación', 'emergency'),
  ],
  running: true,
  selectedAmbulanceId: null,
  selectedEmergencyId: null,
  showNewEmergencyModal: false,
  showDispatchModal: false,
  pickingCoords: false,
  pickedCoords: null,
  pendingDispatch: null,
  avgResponseMinutes: 7.2,
  rejectedAmbulances: [],
};

function reducer(state: AppState, action: AppAction): AppState {
  switch (action.type) {

    case 'TICK': {
      const newHistory: HistoryEntry[] = [];
      let emergencies = [...state.emergencies];

      const ambulances = state.ambulances.map(amb => {
        if (amb.state === 'offline') return amb;

        // Attending timer → return to base
        if (amb.state === 'attending') {
          const elapsed = Date.now() - (amb.attendingStartedAt ?? Date.now());
          if (elapsed >= 10000) {
            const emg = emergencies.find(e => e.id === amb.assignedEmergencyId);
            if (emg) {
              emergencies = emergencies.map(e =>
                e.id === amb.assignedEmergencyId ? { ...e, state: 'resolved' as const } : e
              );
              newHistory.push(makeHistory(`${amb.id} concluye servicio — Regresando a base`, 'resolved'));
            }
            const baseRoute = createDispatchRoute(
              amb.lat, amb.lng,
              amb.baseRoutePoints[0][0], amb.baseRoutePoints[0][1],
            );
            return {
              ...amb, state: 'returning' as const,
              routePoints: baseRoute, routeIndex: 0, speed: 42,
              assignedEmergencyId: undefined, attendingStartedAt: undefined,
            };
          }
          return amb;
        }

        const { updated, atEnd } = tickAmbulance(amb, action.deltaSeconds);

        // Dispatched → arrived at emergency
        if (amb.state === 'dispatched' && atEnd) {
          newHistory.push(makeHistory(`${amb.id} llega al incidente — Atendiendo emergencia`, 'arrival'));
          emergencies = emergencies.map(e =>
            e.id === amb.assignedEmergencyId
              ? { ...e, state: 'active' as const, arrivedAt: Date.now() }
              : e
          );
          return { ...updated, state: 'attending' as const, speed: 0, attendingStartedAt: Date.now() };
        }

        // Returning → arrived at base
        if (amb.state === 'returning' && atEnd) {
          newHistory.push(makeHistory(`${amb.id} regresa a base — Disponible`, 'system'));
          return {
            ...updated, state: 'available' as const,
            routePoints: amb.baseRoutePoints, routeIndex: 0,
            assignedEmergencyId: undefined, speed: 35,
          };
        }

        // Patrol loop
        if (amb.state === 'available' && atEnd) {
          return { ...updated, routeIndex: 0 };
        }

        return updated;
      });

      const allHistory = [...newHistory, ...state.history].slice(0, 60);
      const avgResponse = Math.max(4, state.avgResponseMinutes + (Math.random() - 0.5) * 0.2);

      return { ...state, ambulances, emergencies, history: allHistory, avgResponseMinutes: avgResponse };
    }

    case 'SELECT_AMBULANCE':
      return { ...state, selectedAmbulanceId: action.id };

    case 'SELECT_EMERGENCY':
      return { ...state, selectedEmergencyId: action.id };

    case 'CREATE_EMERGENCY': {
      const histEntry = makeHistory(
        `Nueva emergencia ${action.emergency.id} (${action.emergency.type}) — ${action.emergency.address.split('·')[0].trim()}`,
        'emergency',
      );
      const recs = calculateRecommendations(state.ambulances, action.emergency);
      return {
        ...state,
        emergencies: [action.emergency, ...state.emergencies],
        history: [histEntry, ...state.history].slice(0, 60),
        selectedEmergencyId: action.emergency.id,
        showNewEmergencyModal: false,
        pickingCoords: false,
        pickedCoords: null,
        showDispatchModal: true,
        pendingDispatch: { emergencyId: action.emergency.id, recommendations: recs },
        rejectedAmbulances: [],
      };
    }

    case 'OPEN_DISPATCH': {
      const emergency = state.emergencies.find(e => e.id === action.emergencyId);
      if (!emergency) return state;
      const recs = calculateRecommendations(state.ambulances, emergency);
      return {
        ...state,
        selectedEmergencyId: action.emergencyId,
        showDispatchModal: true,
        pendingDispatch: { emergencyId: action.emergencyId, recommendations: recs },
        rejectedAmbulances: [],
      };
    }

    case 'DISPATCH': {
      const { ambulanceId, emergencyId } = action;
      const emergency = state.emergencies.find(e => e.id === emergencyId);
      const ambulance = state.ambulances.find(a => a.id === ambulanceId);
      if (!emergency || !ambulance) return state;

      const route = createDispatchRoute(ambulance.lat, ambulance.lng, emergency.lat, emergency.lng);
      const histEntry = makeHistory(
        `${ambulanceId} despachada hacia ${emergency.type} en ${emergency.address.split('·')[0].trim()}`,
        'dispatch',
      );

      const ambulances = state.ambulances.map(a =>
        a.id === ambulanceId ? { ...a, state: 'dispatched' as const, routePoints: route, routeIndex: 0, speed: 55, assignedEmergencyId: emergencyId } : a
      );
      const emergencies = state.emergencies.map(e =>
        e.id === emergencyId ? { ...e, state: 'assigned' as const, assignedAmbulanceId: ambulanceId, dispatchedAt: Date.now() } : e
      );

      return {
        ...state, ambulances, emergencies,
        history: [histEntry, ...state.history].slice(0, 60),
        showDispatchModal: false, pendingDispatch: null,
      };
    }

    case 'REJECT_DISPATCH': {
      const histEntry = makeHistory(`${action.ambulanceId} rechazó el servicio`, 'rejection');
      // Recalculate recommendations excluding rejected
      const pd = state.pendingDispatch;
      if (!pd) return state;
      const emergency = state.emergencies.find(e => e.id === pd.emergencyId);
      const newRejected = [...state.rejectedAmbulances, action.ambulanceId];
      const recs = emergency ? calculateRecommendations(state.ambulances, emergency) : pd.recommendations;
      return {
        ...state,
        rejectedAmbulances: newRejected,
        history: [histEntry, ...state.history].slice(0, 60),
        showDispatchModal: true,
        pendingDispatch: { ...pd, recommendations: recs },
      };
    }

    case 'TOGGLE_RUNNING':
      return { ...state, running: !state.running };

    case 'RESET':
      return { ...INITIAL_STATE, history: [makeHistory('Simulación reiniciada', 'system')] };

    case 'PICK_COORDS':
      return { ...state, pickedCoords: { lat: action.lat, lng: action.lng }, pickingCoords: false };

    case 'START_PICKING':
      return { ...state, pickingCoords: true, showNewEmergencyModal: false };

    case 'CANCEL_PICKING':
      return { ...state, pickingCoords: false, showNewEmergencyModal: true };

    case 'OPEN_NEW_EMERGENCY':
      return { ...state, showNewEmergencyModal: true, pickedCoords: null };

    case 'CLOSE_NEW_EMERGENCY':
      return { ...state, showNewEmergencyModal: false, pickingCoords: false, pickedCoords: null };

    case 'CLOSE_DISPATCH_MODAL':
      return { ...state, showDispatchModal: false, pendingDispatch: null };

    case 'TOGGLE_AMBULANCE_OFFLINE': {
      const ambulances = state.ambulances.map(a => {
        if (a.id !== action.id) return a;
        if (a.state === 'offline') {
          return { ...a, state: 'available' as const, speed: 35, lastGpsUpdate: Date.now() };
        }
        return { ...a, state: 'offline' as const, speed: 0 };
      });
      return { ...state, ambulances };
    }

    case 'CREATE_RANDOM_EMERGENCY': {
      const loc = RANDOM_LOCATIONS[Math.floor(Math.random() * RANDOM_LOCATIONS.length)];
      const types: Emergency['type'][] = ['PCR', 'IAM', 'TCE', 'ACCIDENT', 'RESPIRATORY', 'GENERAL'];
      const priorities: Emergency['priority'][] = ['critical', 'critical', 'high', 'high', 'medium'];
      const type = types[Math.floor(Math.random() * types.length)];
      const priority = priorities[Math.floor(Math.random() * priorities.length)];
      const id = `EMG-${String(emgCounter++).padStart(3, '0')}`;
      const emg: Emergency = {
        id, type, priority,
        address: loc.address, lat: loc.lat, lng: loc.lng,
        patients: Math.ceil(Math.random() * 3),
        description: 'Emergencia generada automáticamente por el simulador.',
        state: 'pending', createdAt: Date.now(), resources: [],
      };
      return reducer(state, { type: 'CREATE_EMERGENCY', emergency: emg });
    }

    default:
      return state;
  }
}

interface Toast { id: number; message: string; kind: 'success' | 'error' | 'info' }
let toastCounter = 0;

export default function App() {
  const [state, dispatch] = useReducer(reducer, INITIAL_STATE);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const mapRef = useRef<L.Map | null>(null);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const addToast = useCallback((message: string, kind: Toast['kind'] = 'info') => {
    const id = toastCounter++;
    setToasts(p => [...p, { id, message, kind }]);
    setTimeout(() => setToasts(p => p.filter(t => t.id !== id)), 3500);
  }, []);

  // Simulation loop
  useEffect(() => {
    if (state.running) {
      intervalRef.current = setInterval(() => {
        dispatch({ type: 'TICK', deltaSeconds: 2.5 });
      }, 2500);
    } else {
      if (intervalRef.current) clearInterval(intervalRef.current);
    }
    return () => { if (intervalRef.current) clearInterval(intervalRef.current); };
  }, [state.running]);

  // Pan map to selected ambulance
  useEffect(() => {
    if (state.selectedAmbulanceId && mapRef.current) {
      const amb = state.ambulances.find(a => a.id === state.selectedAmbulanceId);
      if (amb) mapRef.current.panTo([amb.lat, amb.lng], { animate: true });
    }
  }, [state.selectedAmbulanceId]);

  // Pan map to selected emergency
  useEffect(() => {
    if (state.selectedEmergencyId && mapRef.current) {
      const emg = state.emergencies.find(e => e.id === state.selectedEmergencyId);
      if (emg) mapRef.current.setView([emg.lat, emg.lng], 15, { animate: true });
    }
  }, [state.selectedEmergencyId]);

  const handleMapClick = useCallback((lat: number, lng: number) => {
    if (state.pickingCoords) {
      dispatch({ type: 'PICK_COORDS', lat, lng });
      dispatch({ type: 'OPEN_NEW_EMERGENCY' });
    }
  }, [state.pickingCoords]);

  const handleDispatch = useCallback((ambulanceId: string) => {
    const emergencyId = state.pendingDispatch?.emergencyId;
    if (!emergencyId) return;
    dispatch({ type: 'DISPATCH', ambulanceId, emergencyId });
    addToast(`🚑 ${ambulanceId} acepta el servicio — En camino`, 'success');

    // Simulate 10% rejection
    if (Math.random() < 0.10) {
      setTimeout(() => {
        addToast(`⛔ ${ambulanceId} rechazó el servicio`, 'error');
        dispatch({ type: 'REJECT_DISPATCH', ambulanceId });
      }, 2000);
    } else {
      setTimeout(() => addToast(`✅ ${ambulanceId} en ruta al incidente`, 'success'), 2200);
    }
  }, [state.pendingDispatch, addToast]);

  const handleCreateEmergency = useCallback((data: Omit<Emergency, 'id' | 'createdAt' | 'state'>) => {
    const id = `EMG-${String(emgCounter++).padStart(3, '0')}`;
    const emg: Emergency = { ...data, id, createdAt: Date.now(), state: 'pending' };
    dispatch({ type: 'CREATE_EMERGENCY', emergency: emg });
  }, []);

  // KPI calculations
  const available = state.ambulances.filter(a => a.state === 'available').length;
  const busy = state.ambulances.filter(a => a.state !== 'available' && a.state !== 'offline').length;
  const activeEmg = state.emergencies.filter(e => e.state !== 'resolved').length;
  const offline = state.ambulances.filter(a => a.state === 'offline').length;

  const selectedEmergency = state.selectedEmergencyId
    ? state.emergencies.find(e => e.id === state.selectedEmergencyId) ?? null
    : null;

  const pendingEmergency = state.pendingDispatch
    ? state.emergencies.find(e => e.id === state.pendingDispatch!.emergencyId) ?? null
    : null;

  return (
    <div className="app">
      {/* Header */}
      <header className="header">
        <div className="header-logo">
          <div className="header-logo-mark">🚑</div>
          <div>
            <div className="header-logo-text">Fluix</div>
            <div className="header-logo-sub">Sysday Emergencias · Guadalajara</div>
          </div>
        </div>
        <div className="header-divider" />
        <div className="kpi-bar">
          <div className="kpi kpi--green"><span className="kpi-value">{available}</span><span className="kpi-label">Disponibles</span></div>
          <div className="kpi kpi--amber"><span className="kpi-value">{busy}</span><span className="kpi-label">Ocupadas</span></div>
          <div className="kpi kpi--red"><span className="kpi-value">{activeEmg}</span><span className="kpi-label">Activas</span></div>
          <div className="kpi kpi--blue"><span className="kpi-value">{state.avgResponseMinutes.toFixed(1)}m</span><span className="kpi-label">T. Respuesta</span></div>
          <div className="kpi kpi--gray"><span className="kpi-value">{offline}</span><span className="kpi-label">Sin GPS</span></div>
        </div>
        <button className="btn-nueva" onClick={() => dispatch({ type: 'OPEN_NEW_EMERGENCY' })}>
          🚨 NUEVA EMERGENCIA
        </button>
      </header>

      {/* Main */}
      <div className="main">
        <AmbulancePanel
          ambulances={state.ambulances}
          selectedAmbulanceId={state.selectedAmbulanceId}
          selectedEmergency={selectedEmergency}
          onSelect={id => dispatch({ type: 'SELECT_AMBULANCE', id })}
          onToggleOffline={id => dispatch({ type: 'TOGGLE_AMBULANCE_OFFLINE', id })}
        />

        <MapView
          ambulances={state.ambulances}
          emergencies={state.emergencies}
          selectedAmbulanceId={state.selectedAmbulanceId}
          selectedEmergencyId={state.selectedEmergencyId}
          pickingCoords={state.pickingCoords}
          onMapClick={handleMapClick}
          onSelectAmbulance={id => dispatch({ type: 'SELECT_AMBULANCE', id })}
          onSelectEmergency={id => dispatch({ type: 'SELECT_EMERGENCY', id })}
          mapRef={mapRef}
        />

        <div className="panel panel-right" style={{ overflow: 'hidden' }}>
          <EmergencyPanel
            emergencies={state.emergencies}
            selectedEmergencyId={state.selectedEmergencyId}
            onSelect={id => dispatch({ type: 'SELECT_EMERGENCY', id })}
            onDispatch={id => dispatch({ type: 'OPEN_DISPATCH', emergencyId: id })}
          />
          <HistoryLog entries={state.history} />
        </div>
      </div>

      {/* Controls bar */}
      <div className="controls-bar">
        <span className="ctrl-label">Simulación</span>
        <button
          className={`ctrl-btn ${state.running ? 'ctrl-btn--red' : 'ctrl-btn--teal'}`}
          onClick={() => dispatch({ type: 'TOGGLE_RUNNING' })}
        >
          {state.running ? '⏸ Pausar' : '▶ Iniciar'}
        </button>
        <button className="ctrl-btn" onClick={() => dispatch({ type: 'RESET' })}>
          ↺ Reiniciar
        </button>
        <div className="ctrl-sep" />
        <button className="ctrl-btn ctrl-btn--pink" onClick={() => dispatch({ type: 'CREATE_RANDOM_EMERGENCY' })}>
          🎲 Emergencia aleatoria
        </button>
        <button className="ctrl-btn" onClick={() => dispatch({ type: 'OPEN_NEW_EMERGENCY' })}>
          + Nueva emergencia
        </button>
        <div className="ctrl-sep" />
        <span className={`ctrl-status ${state.running ? 'ctrl-status--running' : 'ctrl-status--paused'}`}>
          {state.running ? '● SIMULACIÓN ACTIVA' : '⏸ PAUSADA'}
        </span>
        <span style={{ fontSize: '10px', color: 'rgba(255,255,255,0.3)', marginLeft: '12px' }}>
          CAD v1.0 · Fluix · {new Date().toLocaleTimeString('es-ES')}
        </span>
      </div>

      {/* Modals */}
      {state.showNewEmergencyModal && (
        <NewEmergencyModal
          pickedCoords={state.pickedCoords}
          onPickCoords={() => dispatch({ type: 'START_PICKING' })}
          onClose={() => dispatch({ type: 'CLOSE_NEW_EMERGENCY' })}
          onSubmit={handleCreateEmergency}
        />
      )}

      {state.showDispatchModal && pendingEmergency && state.pendingDispatch && (
        <DispatchModal
          emergency={pendingEmergency}
          recommendations={state.pendingDispatch.recommendations}
          rejectedIds={state.rejectedAmbulances}
          onDispatch={handleDispatch}
          onClose={() => dispatch({ type: 'CLOSE_DISPATCH_MODAL' })}
        />
      )}

      {/* Toasts */}
      <div className="toast-container">
        {toasts.map(t => (
          <div key={t.id} className={`toast toast--${t.kind}`}>{t.message}</div>
        ))}
      </div>
    </div>
  );
}
