export type AmbulanceState = 'available' | 'dispatched' | 'attending' | 'returning' | 'offline';
export type VehicleType = 'SVB' | 'SVA';
export type EmergencyType = 'PCR' | 'IAM' | 'TCE' | 'ACCIDENT' | 'RESPIRATORY' | 'GENERAL';
export type Priority = 'critical' | 'high' | 'medium';
export type EmergencyState = 'pending' | 'assigned' | 'active' | 'resolved';

export interface Ambulance {
  id: string;
  type: VehicleType;
  plate: string;
  crew: string[];
  state: AmbulanceState;
  lat: number;
  lng: number;
  speed: number;
  heading: number;
  lastGpsUpdate: number;
  assignedEmergencyId?: string;
  attendingStartedAt?: number;
  routePoints: [number, number][];
  baseRoutePoints: [number, number][];
  routeIndex: number;
  zone: string;
}

export interface Emergency {
  id: string;
  type: EmergencyType;
  priority: Priority;
  address: string;
  lat: number;
  lng: number;
  patients: number;
  description: string;
  state: EmergencyState;
  assignedAmbulanceId?: string;
  createdAt: number;
  dispatchedAt?: number;
  arrivedAt?: number;
  resources: string[];
}

export interface DispatchRecommendation {
  ambulanceId: string;
  distanceKm: number;
  etaMinutes: number;
  available: boolean;
  reason?: string;
  typeMatch: boolean;
}

export interface HistoryEntry {
  id: string;
  timestamp: number;
  message: string;
  category: 'emergency' | 'dispatch' | 'arrival' | 'resolved' | 'system' | 'rejection';
  priority?: Priority;
}

export interface AppState {
  ambulances: Ambulance[];
  emergencies: Emergency[];
  history: HistoryEntry[];
  running: boolean;
  selectedAmbulanceId: string | null;
  selectedEmergencyId: string | null;
  showNewEmergencyModal: boolean;
  showDispatchModal: boolean;
  pickingCoords: boolean;
  pickedCoords: { lat: number; lng: number } | null;
  pendingDispatch: {
    emergencyId: string;
    recommendations: DispatchRecommendation[];
  } | null;
  avgResponseMinutes: number;
  rejectedAmbulances: string[];
}

export type AppAction =
  | { type: 'TICK'; deltaSeconds: number }
  | { type: 'SELECT_AMBULANCE'; id: string | null }
  | { type: 'SELECT_EMERGENCY'; id: string | null }
  | { type: 'CREATE_EMERGENCY'; emergency: Emergency }
  | { type: 'OPEN_DISPATCH'; emergencyId: string }
  | { type: 'DISPATCH'; ambulanceId: string; emergencyId: string }
  | { type: 'REJECT_DISPATCH'; ambulanceId: string }
  | { type: 'COMPLETE_EMERGENCY'; emergencyId: string }
  | { type: 'TOGGLE_RUNNING' }
  | { type: 'RESET' }
  | { type: 'PICK_COORDS'; lat: number; lng: number }
  | { type: 'START_PICKING' }
  | { type: 'CANCEL_PICKING' }
  | { type: 'OPEN_NEW_EMERGENCY' }
  | { type: 'CLOSE_NEW_EMERGENCY' }
  | { type: 'CLOSE_DISPATCH_MODAL' }
  | { type: 'TOGGLE_AMBULANCE_OFFLINE'; id: string }
  | { type: 'CREATE_RANDOM_EMERGENCY' };

export const EMERGENCY_LABELS: Record<EmergencyType, string> = {
  PCR: 'PCR — Parada Cardiorrespiratoria',
  IAM: 'IAM — Infarto Agudo de Miocardio',
  TCE: 'TCE — Traumatismo Craneoencefálico',
  ACCIDENT: 'Accidente de Tráfico',
  RESPIRATORY: 'Urgencia Respiratoria',
  GENERAL: 'Urgencia Médica General',
};

export const PRIORITY_LABELS: Record<Priority, string> = {
  critical: 'Crítica',
  high: 'Alta',
  medium: 'Media',
};

export const STATE_LABELS: Record<AmbulanceState, string> = {
  available: 'Disponible',
  dispatched: 'En desplazamiento',
  attending: 'Atendiendo',
  returning: 'Regresando',
  offline: 'Sin conexión',
};

export const STATE_COLORS: Record<AmbulanceState, string> = {
  available: '#16A34A',
  dispatched: '#3B82F6',
  attending: '#F59E0B',
  returning: '#8B5CF6',
  offline: '#94A3B8',
};

export const PRIORITY_COLORS: Record<Priority, string> = {
  critical: '#EF4444',
  high: '#F97316',
  medium: '#EAB308',
};
