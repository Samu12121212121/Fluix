import type { Ambulance } from './types';

export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function bearing(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const y = Math.sin(dLng) * Math.cos((lat2 * Math.PI) / 180);
  const x =
    Math.cos((lat1 * Math.PI) / 180) * Math.sin((lat2 * Math.PI) / 180) -
    Math.sin((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.cos(dLng);
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

function lerp(a: number, b: number, t: number) {
  return a + (b - a) * t;
}

export function tickAmbulance(
  amb: Ambulance,
  deltaSeconds: number,
): { updated: Ambulance; atEnd: boolean } {
  if (amb.state === 'offline' || amb.state === 'attending') {
    return { updated: amb, atEnd: false };
  }

  const pts = amb.routePoints;
  if (pts.length < 2) return { updated: amb, atEnd: false };

  let { routeIndex } = amb;
  let lat = amb.lat;
  let lng = amb.lng;
  let head = amb.heading;
  let atEnd = false;

  const speedKmh =
    amb.state === 'dispatched' ? 55 + Math.random() * 10 :
    amb.state === 'returning'  ? 42 + Math.random() * 6 :
                                 28 + Math.random() * 18;

  const moveKm = (speedKmh / 3600) * deltaSeconds;
  let remaining = moveKm;

  while (remaining > 0 && routeIndex < pts.length - 1) {
    const target = pts[routeIndex];
    const distKm = haversineKm(lat, lng, target[0], target[1]);

    if (distKm <= 0.015) {
      // Reached this waypoint
      lat = target[0];
      lng = target[1];
      routeIndex++;

      if (routeIndex >= pts.length - 1) {
        lat = pts[pts.length - 1][0];
        lng = pts[pts.length - 1][1];
        atEnd = true;
        break;
      }
      continue;
    }

    if (remaining >= distKm) {
      remaining -= distKm;
      lat = target[0];
      lng = target[1];
      routeIndex++;
    } else {
      const fraction = remaining / distKm;
      head = bearing(lat, lng, target[0], target[1]);
      lat = lerp(lat, target[0], fraction);
      lng = lerp(lng, target[1], fraction);
      remaining = 0;
    }
  }

  // Patrol loop
  if (!atEnd && routeIndex >= pts.length - 1 && amb.state === 'available') {
    routeIndex = 0;
  }

  return {
    updated: {
      ...amb,
      lat,
      lng,
      heading: head,
      speed: Math.round(speedKmh),
      routeIndex,
      lastGpsUpdate: Date.now(),
    },
    atEnd,
  };
}

export function createDispatchRoute(
  fromLat: number, fromLng: number,
  toLat: number, toLng: number,
): [number, number][] {
  const midLat = (fromLat + toLat) / 2;
  const midLng = (fromLng + toLng) / 2;
  // Street-like jitter
  const j = 0.003;
  const jLat = (Math.random() - 0.5) * j;
  const jLng = (Math.random() - 0.5) * j;
  return [
    [fromLat, fromLng],
    [midLat + jLat, midLng + jLng],
    [toLat, toLng],
  ];
}
