import type { Ambulance, Emergency, DispatchRecommendation } from './types';
import { haversineKm } from './simulation';

function requiresSVA(type: Emergency['type']): boolean {
  return type === 'PCR' || type === 'IAM';
}

export function calculateRecommendations(
  ambulances: Ambulance[],
  emergency: Emergency,
): DispatchRecommendation[] {
  const needsSVA = requiresSVA(emergency.type);

  const recs: DispatchRecommendation[] = ambulances.map(amb => {
    if (amb.state === 'offline') {
      return { ambulanceId: amb.id, distanceKm: 0, etaMinutes: 0, available: false, reason: 'Sin conexión GPS', typeMatch: false };
    }
    if (amb.state !== 'available') {
      const labels: Record<string, string> = {
        dispatched: 'En desplazamiento',
        attending: 'Atendiendo emergencia',
        returning: 'Regresando a base',
      };
      return { ambulanceId: amb.id, distanceKm: 0, etaMinutes: 0, available: false, reason: labels[amb.state] ?? amb.state, typeMatch: false };
    }

    const straight = haversineKm(amb.lat, amb.lng, emergency.lat, emergency.lng);
    const roadDist = straight * 1.35;
    const avgSpeedKmh = emergency.priority === 'critical' ? 60 : 50;
    const etaMinutes = (roadDist / avgSpeedKmh) * 60;
    const typeMatch = !needsSVA || amb.type === 'SVA';

    return { ambulanceId: amb.id, distanceKm: roadDist, etaMinutes, available: true, typeMatch };
  });

  return recs.sort((a, b) => {
    // Available first
    if (a.available && !b.available) return -1;
    if (!a.available && b.available) return 1;
    if (!a.available && !b.available) return 0;
    // Among available: SVA match first for critical types
    if (needsSVA && a.typeMatch !== b.typeMatch) return a.typeMatch ? -1 : 1;
    // Then by ETA
    return a.etaMinutes - b.etaMinutes;
  });
}

export function formatDistance(km: number): string {
  if (km < 1) return `${Math.round(km * 1000)} m`;
  return `${km.toFixed(1)} km`;
}

export function formatEta(minutes: number): string {
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return `${Math.round(minutes)} min`;
  const h = Math.floor(minutes / 60);
  const m = Math.round(minutes % 60);
  return `${h}h ${m}min`;
}
