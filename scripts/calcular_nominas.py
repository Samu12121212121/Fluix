#!/usr/bin/env python3
"""
Calcula y escribe nóminas de noviembre 2026 para Sysday Emergencias Sanitarias.
Lee empleados de Firestore y escribe nóminas usando la REST API.
"""
import sys, json, math, uuid, os
import urllib.request, urllib.error

TOKEN      = os.environ.get('GCLOUD_TOKEN', '')
PROJECT    = 'planeaapp-4bea4'
EMPRESA_ID = 'demo_ambulancias_guadalajara_2026'
MES, ANIO  = 11, 2026
BASE_URL   = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents'

if not TOKEN:
    print(' Falta GCLOUD_TOKEN')
    sys.exit(1)

def fs_post(path, body):
    url  = BASE_URL + path
    data = json.dumps(body).encode('utf-8')
    req  = urllib.request.Request(url, data=data,
                                  headers={'Authorization': f'Bearer {TOKEN}',
                                           'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

# ── Normativa SS 2026 ─────────────────────────────────────────────────────────
SS_TRAB = 0.0470 + 0.0155 + 0.0010 + 0.0012  # 6.47%
SS_EMP  = 0.2360 + 0.0550 + 0.0020 + 0.0060 + 0.0150 + 0.0058  # 33.98%
BC_MIN, BC_MAX = 1260.0, 4720.5

def calc_irpf_anual(base):
    tramos = [(12450,0.19),(20200,0.24),(35200,0.30),(60000,0.37),(300000,0.45)]
    cuota, prev = 0.0, 0.0
    for hasta, tipo in tramos:
        if base <= prev: break
        cuota += (min(base, hasta) - prev) * tipo
        prev = hasta
        if base <= hasta: break
    if base > 300000:
        cuota += (base - 300000) * 0.47
    return cuota

def reduccion_trabajo(renta):
    if renta <= 14450:   return 7302.0
    if renta <= 19747.5: return max(0.0, 7302 - 1.75*(renta-14450))
    return 0.0

def minimo_familiar(hijos, menores3, discapacidad):
    m = 5550.0
    if hijos >= 1: m += 2400
    if hijos >= 2: m += 2700
    if hijos >= 3: m += 4000
    if hijos >= 4: m += 4500
    m += 2800 * menores3
    if discapacidad: m += 3000
    return m

# ── Verificar que no existen nóminas ──────────────────────────────────────────
print(f'Verificando nominas existentes para {MES}/{ANIO}...')

def fs_post_parent(parent_path, body):
    url  = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents{parent_path}:runQuery'
    data = json.dumps(body).encode('utf-8')
    req  = urllib.request.Request(url, data=data,
                                  headers={'Authorization': f'Bearer {TOKEN}',
                                           'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

check = fs_post_parent(f'/empresas/{EMPRESA_ID}', {'structuredQuery': {
    'from': [{'collectionId': 'nominas'}],
    'where': {'compositeFilter': {'op': 'AND', 'filters': [
        {'fieldFilter': {'field': {'fieldPath': 'mes'},  'op': 'EQUAL', 'value': {'integerValue': str(MES)}}},
        {'fieldFilter': {'field': {'fieldPath': 'anio'}, 'op': 'EQUAL', 'value': {'integerValue': str(ANIO)}}},
        {'fieldFilter': {'field': {'fieldPath': 'es_correccion'}, 'op': 'EQUAL', 'value': {'booleanValue': False}}},
    ]}},
    'limit': 1,
}})
existentes = [item for item in check if 'document' in item]
if existentes:
    print(f'Ya existen nominas para {MES}/{ANIO}. Abortando.')
    sys.exit(0)
print('  0 nominas existentes, continuando...')

# ── Cargar empleados ──────────────────────────────────────────────────────────
print('\n Cargando empleados...')
resp = fs_post(':runQuery', {'structuredQuery': {
    'from': [{'collectionId': 'usuarios'}],
    'where': {'compositeFilter': {'op': 'AND', 'filters': [
        {'fieldFilter': {'field': {'fieldPath': 'empresa_id'}, 'op': 'EQUAL', 'value': {'stringValue': EMPRESA_ID}}},
        {'fieldFilter': {'field': {'fieldPath': 'activo'},     'op': 'EQUAL', 'value': {'booleanValue': True}}},
    ]}},
}})
empleados = [item for item in resp if 'document' in item]
print(f'  Total activos: {len(empleados)}')

# ── Calcular nóminas ──────────────────────────────────────────────────────────
def fv(fields, key, default=0.0):
    v = fields.get(key, {})
    if 'doubleValue'  in v: return float(v['doubleValue'])
    if 'integerValue' in v: return float(v['integerValue'])
    if 'stringValue'  in v: return v['stringValue']
    if 'booleanValue' in v: return v['booleanValue']
    return default

writes = []
skipped = 0

for item in empleados:
    doc  = item['document']
    uid  = doc['name'].split('/')[-1]
    f    = doc.get('fields', {})
    nombre = fv(f, 'nombre', 'Sin nombre')
    dn_field = f.get('datos_nomina', {}).get('mapValue', {}).get('fields', {})
    if not dn_field:
        skipped += 1; continue

    salario   = float(fv(dn_field, 'salario_bruto_anual') or 0)
    if salario < 15876:
        skipped += 1; continue

    comp_fijo = float(fv(dn_field, 'complemento_fijo') or 0)
    horas_sem = float(fv(dn_field, 'horas_semanales') or 40)
    coef      = horas_sem / 40.0
    nif       = fv(dn_field, 'nif', '')
    nss       = fv(dn_field, 'nss', '')
    hijos     = int(fv(dn_field, 'num_hijos') or 0)
    menores3  = int(fv(dn_field, 'num_hijos_menores_3') or 0)
    disc      = bool(fv(dn_field, 'discapacidad') or False)

    sal_mes       = round((salario / 12) * coef, 2)
    total_devengos = round(sal_mes + comp_fijo, 2)
    bc            = max(BC_MIN, min(BC_MAX, total_devengos))
    ss_trab       = round(bc * SS_TRAB, 2)
    ss_emp        = round(bc * SS_EMP, 2)

    base_anual    = salario + comp_fijo * 12
    red_trab      = reduccion_trabajo(base_anual)
    min_fam       = minimo_familiar(hijos, menores3, disc)
    irpf_bruto    = calc_irpf_anual(base_anual - red_trab)
    irpf_boni     = calc_irpf_anual(min_fam) * 0.19
    irpf_neto_anual = max(0.0, irpf_bruto - irpf_boni)
    tipo          = irpf_neto_anual / base_anual if base_anual > 0 else 0.0
    ret_irpf      = round(total_devengos * tipo, 2)

    neto          = round(total_devengos - ss_trab - ret_irpf, 2)
    coste         = round(total_devengos + ss_emp, 2)
    nomina_id     = uuid.uuid4().hex[:20]

    doc_name = f'projects/{PROJECT}/databases/(default)/documents/empresas/{EMPRESA_ID}/nominas/{nomina_id}'

    payload = {
        'empresa_id':          {'stringValue': EMPRESA_ID},
        'empleado_id':         {'stringValue': uid},
        'empleado_nombre':     {'stringValue': nombre},
        'empleado_nif':        {'stringValue': str(nif)},
        'empleado_nss':        {'stringValue': str(nss)},
        'mes':                 {'integerValue': str(MES)},
        'anio':                {'integerValue': str(ANIO)},
        'periodo':             {'stringValue': 'noviembre 2026'},
        'estado':              {'stringValue': 'borrador'},
        'salario_bruto_mensual': {'doubleValue': sal_mes},
        'complemento_fijo':    {'doubleValue': comp_fijo},
        'total_devengos':      {'doubleValue': total_devengos},
        'base_cotizacion':     {'doubleValue': round(bc, 2)},
        'ss_trabajador':       {'doubleValue': ss_trab},
        'total_ss_trabajador': {'doubleValue': ss_trab},
        'retencion_irpf':      {'doubleValue': ret_irpf},
        'tipo_irpf':           {'doubleValue': round(tipo, 4)},
        'total_deducciones':   {'doubleValue': round(ss_trab + ret_irpf, 2)},
        'salario_neto':        {'doubleValue': neto},
        'ss_empresa':          {'doubleValue': ss_emp},
        'total_ss_empresa':    {'doubleValue': ss_emp},
        'coste_total_empresa': {'doubleValue': coste},
        'salario_bruto_anual': {'doubleValue': salario},
        'horas_extra':         {'doubleValue': 0.0},
        'importe_horas_extra': {'doubleValue': 0.0},
        'complementos_variables': {'doubleValue': 0.0},
        'descuento_ausencias': {'doubleValue': 0.0},
        'es_correccion':       {'booleanValue': False},
        'irpf_ajustado':       {'booleanValue': False},
        'notas':               {'stringValue': ''},
        'tipo_hora_extra':     {'stringValue': 'no_estructural'},
        'base_acumulada_ytd':  {'doubleValue': round(salario / 12 * (MES - 1), 2)},
        'irpf_acumulado_ytd':  {'doubleValue': round(ret_irpf * (MES - 1), 2)},
    }

    writes.append({
        'update': {
            'name': doc_name,
            'fields': payload,
        }
    })
    print(f'   {nombre[:30].ljust(32)} | {neto:>8.2f} | IRPF {tipo*100:.1f}%')

print(f'\n Resumen: {len(writes)} nminas listas, {skipped} omitidas')
if not writes:
    print('Nada que escribir.')
    sys.exit(0)

total_neto  = 0.0
total_coste = 0.0
for w in writes:
    f2 = w['update']['fields']
    total_neto  += f2['salario_neto']['doubleValue']
    total_coste += f2['coste_total_empresa']['doubleValue']
print(f'   Total neto empleados: {total_neto:>10,.2f} ')
print(f'   Total coste empresa:  {total_coste:>10,.2f} ')

# ── Escribir en Firestore (lotes de 500) ──────────────────────────────────────
print(f'\n Escribiendo en Firestore...')
BATCH = 500
total_escritas = 0
for i in range(0, len(writes), BATCH):
    lote = writes[i:i+BATCH]
    fs_post(':batchWrite', {'writes': lote})
    total_escritas += len(lote)
    print(f'   Lote {i//BATCH+1}: {len(lote)} nminas escritas')

print(f'\n {total_escritas} nminas generadas en estado BORRADOR')
print(f'   Empresa: Sysday Emergencias Sanitarias')
print(f'   Perodo: noviembre 2026')
print(f'   Accede desde Fluix  Nminas para aprobarlas\n')
