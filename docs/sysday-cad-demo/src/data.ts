import type { Ambulance, Emergency } from './types';

// Patrol routes — waypoints following real streets of Guadalajara, Spain
// AMB-01: Hospital → Centro → Estación → loop
const route01: [number, number][] = [
  [40.6264, -3.1660], // Hospital Universitario
  [40.6282, -3.1672], // C/ Cardenal González de Mendoza
  [40.6307, -3.1676], // C/ Alfonso VIII
  [40.6333, -3.1663], // Plaza Mayor / Centro
  [40.6351, -3.1638], // C/ Mayor Este
  [40.6364, -3.1594], // Av. del Ejército
  [40.6341, -3.1554], // C/ Obispo Ángel Hidalgo
  [40.6314, -3.1535], // Estación Autobuses
  [40.6294, -3.1550], // C/ Albarracín
  [40.6270, -3.1597], // Barranco del Alamín
  [40.6264, -3.1660], // back to Hospital
];

// AMB-02: Polígono El Balconcillo → Av. Castilla → Hospital → loop
const route02: [number, number][] = [
  [40.6183, -3.1775], // Polígono El Balconcillo
  [40.6213, -3.1738], // C/ Hispanidad
  [40.6242, -3.1707], // Av. de Castilla
  [40.6265, -3.1690], // near Hospital W
  [40.6295, -3.1680], // C/ Cardenal Lorenzana
  [40.6333, -3.1668], // Centro
  [40.6355, -3.1640], // Av. del Ejército W
  [40.6371, -3.1597], // Av. del Ejército E
  [40.6350, -3.1549], // C/ Alvar Fáñez
  [40.6300, -3.1537], // near Estación
  [40.6253, -3.1601], // Circunvalación S
  [40.6183, -3.1775], // back to Polígono
];

// AMB-03: Zona Este → Centro → Zona Oeste
const route03: [number, number][] = [
  [40.6342, -3.1498], // Barrio Aguas Vivas (E)
  [40.6335, -3.1540], // C/ Sigüenza
  [40.6330, -3.1572], // C/ Medina
  [40.6334, -3.1621], // C/ Fernández Iparraguirre
  [40.6336, -3.1668], // Centro / Plaza Mayor
  [40.6338, -3.1700], // C/ General Moscardó (W)
  [40.6330, -3.1742], // Paseo de las Cruces
  [40.6310, -3.1728], // C/ Alonso Coello
  [40.6294, -3.1703], // near Hospital W
  [40.6300, -3.1650], // C/ Cardenal Lorenzana S
  [40.6342, -3.1498], // back to Este
];

// AMB-04: Zona Norte → Av. Ejército → Hospital → loop
const route04: [number, number][] = [
  [40.6422, -3.1649], // Norte Guadalajara
  [40.6401, -3.1621], // C/ Palancares
  [40.6382, -3.1611], // Av. del Ejército Centro
  [40.6360, -3.1578], // Av. del Ejército E
  [40.6340, -3.1551], // C/ Obispo Ángel Hidalgo
  [40.6314, -3.1535], // Estación
  [40.6288, -3.1558], // C/ Ferial
  [40.6267, -3.1620], // Barranco del Alamín
  [40.6264, -3.1660], // Hospital Universitario
  [40.6282, -3.1702], // C/ Juan de Villanueva
  [40.6315, -3.1710], // Hospital W approach
  [40.6356, -3.1682], // C/ Cardenal Lorenzana N
  [40.6422, -3.1649], // back Norte
];

// AMB-05: Zona Sur → Hospital → Centro (starts offline)
const route05: [number, number][] = [
  [40.6152, -3.1658], // Sur / CM-200
  [40.6183, -3.1672], // Acceso Sur
  [40.6213, -3.1667], // C/ Cardenal Lorenzana S
  [40.6243, -3.1663], // Hospital S
  [40.6264, -3.1660], // Hospital Universitario
  [40.6295, -3.1653], // Hospital N entrance
  [40.6320, -3.1660], // C/ Cardenal González N
  [40.6334, -3.1658], // Centro
  [40.6300, -3.1638], // C/ Juan Villamajor
  [40.6267, -3.1638], // Barranco E
  [40.6243, -3.1648], // Hospital S approach
  [40.6152, -3.1658], // back Sur
];

export const INITIAL_AMBULANCES: Ambulance[] = [
  {
    id: 'AMB-01',
    type: 'SVB',
    plate: '0001-GUA',
    crew: ['Carlos Pérez (TES)', 'Ana Molina (TES)'],
    state: 'available',
    lat: route01[0][0],
    lng: route01[0][1],
    speed: 42,
    heading: 15,
    lastGpsUpdate: Date.now(),
    routePoints: route01,
    baseRoutePoints: route01,
    routeIndex: 1,
    zone: 'Hospital / Centro',
  },
  {
    id: 'AMB-02',
    type: 'SVA',
    plate: '0002-GUA',
    crew: ['Javier Torres (DUE)', 'Carmen Ruiz (Médico)', 'Luis García (TES)'],
    state: 'available',
    lat: route02[2][0],
    lng: route02[2][1],
    speed: 38,
    heading: 45,
    lastGpsUpdate: Date.now(),
    routePoints: route02,
    baseRoutePoints: route02,
    routeIndex: 3,
    zone: 'Av. Castilla / Hospital',
  },
  {
    id: 'AMB-03',
    type: 'SVB',
    plate: '0003-GUA',
    crew: ['Marta Blanco (TES)', 'Roberto Díaz (TES)'],
    state: 'available',
    lat: route03[0][0],
    lng: route03[0][1],
    speed: 35,
    heading: 270,
    lastGpsUpdate: Date.now(),
    routePoints: route03,
    baseRoutePoints: route03,
    routeIndex: 1,
    zone: 'Zona Este',
  },
  {
    id: 'AMB-04',
    type: 'SVA',
    plate: '0004-GUA',
    crew: ['Elena Sánchez (Médico)', 'Pablo Moreno (DUE)', 'Sofía Castro (TES)'],
    state: 'available',
    lat: route04[0][0],
    lng: route04[0][1],
    speed: 44,
    heading: 190,
    lastGpsUpdate: Date.now(),
    routePoints: route04,
    baseRoutePoints: route04,
    routeIndex: 1,
    zone: 'Zona Norte',
  },
  {
    id: 'AMB-05',
    type: 'SVB',
    plate: '0005-GUA',
    crew: ['Adrián López (TES)', 'Natalia Vega (TES)'],
    state: 'offline',
    lat: route05[0][0],
    lng: route05[0][1],
    speed: 0,
    heading: 90,
    lastGpsUpdate: Date.now() - 540000,
    routePoints: route05,
    baseRoutePoints: route05,
    routeIndex: 0,
    zone: 'Zona Sur',
  },
];

export const SAMPLE_EMERGENCIES: Emergency[] = [
  {
    id: 'EMG-001',
    type: 'PCR',
    priority: 'critical',
    address: 'Av. del Ejército, 15 · Guadalajara',
    lat: 40.6367,
    lng: -3.1612,
    patients: 1,
    description: 'Varón de 62 años, pérdida de conocimiento, posible parada cardiorrespiratoria. Testigos realizan RCP.',
    state: 'pending',
    createdAt: Date.now() - 180000,
    resources: ['DEA', 'O2', 'Monitor cardíaco'],
  },
  {
    id: 'EMG-002',
    type: 'ACCIDENT',
    priority: 'high',
    address: 'C/ Albarracín, 5 · Guadalajara',
    lat: 40.6314,
    lng: -3.1545,
    patients: 2,
    description: 'Colisión frontal entre dos vehículos. Un herido atrapado, otro con politraumatismos.',
    state: 'pending',
    createdAt: Date.now() - 300000,
    resources: ['Collarín', 'Tabla espinal', 'Férulas'],
  },
  {
    id: 'EMG-003',
    type: 'IAM',
    priority: 'critical',
    address: 'Plaza Mayor, 3 · Guadalajara',
    lat: 40.6336,
    lng: -3.1663,
    patients: 1,
    description: 'Mujer de 55 años con dolor torácico irradiado a brazo izquierdo y dificultad respiratoria.',
    state: 'pending',
    createdAt: Date.now() - 420000,
    resources: ['Monitor ECG', 'Nitratos', 'Acceso venoso'],
  },
];

export const RANDOM_LOCATIONS: { address: string; lat: number; lng: number }[] = [
  { address: 'C/ Mayor, 22 · Guadalajara', lat: 40.6338, lng: -3.1680 },
  { address: 'Av. del Ejército, 45 · Guadalajara', lat: 40.6372, lng: -3.1588 },
  { address: 'C/ Cardenal Lorenzana, 12 · Guadalajara', lat: 40.6295, lng: -3.1680 },
  { address: 'Paseo de las Cruces, 8 · Guadalajara', lat: 40.6330, lng: -3.1742 },
  { address: 'Av. de Castilla, 30 · Guadalajara', lat: 40.6240, lng: -3.1710 },
  { address: 'C/ Sigüenza, 15 · Guadalajara', lat: 40.6335, lng: -3.1540 },
  { address: 'C/ Palancares, 7 · Guadalajara', lat: 40.6401, lng: -3.1621 },
  { address: 'C/ Hispanidad, 20 · Guadalajara', lat: 40.6213, lng: -3.1738 },
  { address: 'Polígono El Balconcillo, Nave 14 · Guadalajara', lat: 40.6185, lng: -3.1770 },
  { address: 'C/ Alfonso VIII, 5 · Guadalajara', lat: 40.6307, lng: -3.1676 },
  { address: 'C/ Ferial, 3 · Guadalajara', lat: 40.6288, lng: -3.1558 },
  { address: 'Av. Venezuela, 10 · Guadalajara', lat: 40.6250, lng: -3.1580 },
];
