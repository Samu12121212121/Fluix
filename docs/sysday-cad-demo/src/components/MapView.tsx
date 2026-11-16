import { useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Polyline, useMapEvents, useMap } from 'react-leaflet';
import L from 'leaflet';
import type { Ambulance, Emergency } from '../types';
import { STATE_COLORS, PRIORITY_COLORS } from '../types';

function ambIcon(amb: Ambulance): L.DivIcon {
  const color = STATE_COLORS[amb.state];
  const rot = amb.heading;
  return L.divIcon({
    className: '',
    iconSize: [36, 44],
    iconAnchor: [18, 22],
    html: `
      <div class="amb-icon" style="transform: rotate(${rot}deg); transform-origin: center 18px;">
        <div class="amb-icon-vehicle">🚑</div>
      </div>
      <div class="amb-icon-label" style="background:${color}; position:absolute; bottom:-2px; left:50%; transform:translateX(-50%);">
        ${amb.id}
      </div>`,
  });
}

function emgIcon(emg: Emergency): L.DivIcon {
  const color = PRIORITY_COLORS[emg.priority];
  const letter = emg.type === 'PCR' ? '♥' : emg.type === 'IAM' ? '♥' : emg.type === 'ACCIDENT' ? '⚠' : '!';
  const pulseClass = emg.priority === 'critical' ? 'emg-icon--critical' : '';
  return L.divIcon({
    className: '',
    iconSize: [24, 24],
    iconAnchor: [12, 12],
    html: `<div class="emg-icon ${pulseClass}" style="background:${color};">${letter}</div>`,
  });
}

interface MapClickHandlerProps {
  active: boolean;
  onMapClick: (lat: number, lng: number) => void;
}
function MapClickHandler({ active, onMapClick }: MapClickHandlerProps) {
  useMapEvents({
    click(e) {
      if (active) onMapClick(e.latlng.lat, e.latlng.lng);
    },
  });
  return null;
}

interface MapControllerProps {
  mapRef: React.MutableRefObject<L.Map | null>;
}
function MapController({ mapRef }: MapControllerProps) {
  const map = useMap();
  useEffect(() => { mapRef.current = map; }, [map, mapRef]);
  return null;
}

interface Props {
  ambulances: Ambulance[];
  emergencies: Emergency[];
  selectedAmbulanceId: string | null;
  selectedEmergencyId: string | null;
  pickingCoords: boolean;
  onMapClick: (lat: number, lng: number) => void;
  onSelectAmbulance: (id: string) => void;
  onSelectEmergency: (id: string) => void;
  mapRef: React.MutableRefObject<L.Map | null>;
}

export default function MapView({
  ambulances, emergencies, selectedAmbulanceId, selectedEmergencyId,
  pickingCoords, onMapClick, onSelectAmbulance, onSelectEmergency, mapRef,
}: Props) {
  return (
    <div className={`map-wrap ${pickingCoords ? 'map-picking' : ''}`}>
      {pickingCoords && (
        <div className="map-picking-hint">📍 Haz clic en el mapa para seleccionar la ubicación</div>
      )}
      <MapContainer
        center={[40.6333, -3.1667]}
        zoom={14}
        style={{ width: '100%', height: '100%' }}
        zoomControl={true}
      >
        <MapController mapRef={mapRef} />
        <MapClickHandler active={pickingCoords} onMapClick={onMapClick} />

        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          maxZoom={19}
        />

        {/* Dispatch / return route polylines */}
        {ambulances
          .filter(a => (a.state === 'dispatched' || a.state === 'returning') && a.routePoints.length > 1)
          .map(a => (
            <Polyline
              key={`route-${a.id}`}
              positions={a.routePoints}
              color={a.state === 'dispatched' ? '#00FFC8' : '#8B5CF6'}
              weight={3}
              dashArray={a.state === 'dispatched' ? '8 4' : '4 8'}
              opacity={0.85}
            />
          ))}

        {/* Selected ambulance patrol trail */}
        {ambulances
          .filter(a => a.id === selectedAmbulanceId && a.state === 'available')
          .map(a => (
            <Polyline
              key={`patrol-${a.id}`}
              positions={a.baseRoutePoints}
              color="#94A3B8"
              weight={1.5}
              dashArray="4 6"
              opacity={0.5}
            />
          ))}

        {/* Emergency markers */}
        {emergencies
          .filter(e => e.state !== 'resolved')
          .map(emg => (
            <Marker
              key={emg.id}
              position={[emg.lat, emg.lng]}
              icon={emgIcon(emg)}
              zIndexOffset={emg.id === selectedEmergencyId ? 200 : 100}
              eventHandlers={{ click: () => onSelectEmergency(emg.id) }}
            />
          ))}

        {/* Ambulance markers */}
        {ambulances.map(amb => (
          <Marker
            key={amb.id}
            position={[amb.lat, amb.lng]}
            icon={ambIcon(amb)}
            zIndexOffset={amb.id === selectedAmbulanceId ? 300 : 200}
            eventHandlers={{ click: () => onSelectAmbulance(amb.id) }}
          />
        ))}
      </MapContainer>
    </div>
  );
}
