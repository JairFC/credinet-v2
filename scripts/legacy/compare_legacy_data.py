#!/usr/bin/env python3
"""
Comparación de datos PDF vs Base de Datos - Tabla Legacy
"""

# Datos del PDF (fuente de verdad)
pdf_data = {
    3000: {'asociado': 337, 'cliente': 392, 'comision': 55},
    4000: {'asociado': 446, 'cliente': 510, 'comision': 64},
    5000: {'asociado': 553, 'cliente': 633, 'comision': 80},
    6000: {'asociado': 662, 'cliente': 752, 'comision': 90},
    7000: {'asociado': 770, 'cliente': 882, 'comision': 112},
    8000: {'asociado': 878, 'cliente': 1006, 'comision': 128},
    9000: {'asociado': 987, 'cliente': 1131, 'comision': 144},
    10000: {'asociado': 1095, 'cliente': 1255, 'comision': 160},
    11000: {'asociado': 1215, 'cliente': 1385, 'comision': 170},
    12000: {'asociado': 1324, 'cliente': 1504, 'comision': 180},
    13000: {'asociado': 1432, 'cliente': 1634, 'comision': 202},
    14000: {'asociado': 1541, 'cliente': 1765, 'comision': 224},
    15000: {'asociado': 1648, 'cliente': 1888, 'comision': 240},
    16000: {'asociado': 1756, 'cliente': 2012, 'comision': 256},
    17000: {'asociado': 1865, 'cliente': 2137, 'comision': 272},
    18000: {'asociado': 1974, 'cliente': 2262, 'comision': 288},
    19000: {'asociado': 2082, 'cliente': 2386, 'comision': 304},
    20000: {'asociado': 2190, 'cliente': 2510, 'comision': 320},
    21000: {'asociado': 2310, 'cliente': 2640, 'comision': 330},
    22000: {'asociado': 2419, 'cliente': 2759, 'comision': 340},
    23000: {'asociado': 2527, 'cliente': 2889, 'comision': 362},
    24000: {'asociado': 2636, 'cliente': 3020, 'comision': 384},
    25000: {'asociado': 2743, 'cliente': 3143, 'comision': 400},
    26000: {'asociado': 2851, 'cliente': 3267, 'comision': 416},
    27000: {'asociado': 2960, 'cliente': 3392, 'comision': 432},
    28000: {'asociado': 3069, 'cliente': 3517, 'comision': 448},
    29000: {'asociado': 3177, 'cliente': 3641, 'comision': 464},
    30000: {'asociado': 3285, 'cliente': 3765, 'comision': 480},
}

# Datos de la base de datos actual
db_data = {
    3000: {'asociado': 337, 'cliente': 392, 'comision': 55},
    4000: {'asociado': 446, 'cliente': 510, 'comision': 64},
    5000: {'asociado': 553, 'cliente': 633, 'comision': 80},
    6000: {'asociado': 662, 'cliente': 752, 'comision': 90},
    7000: {'asociado': 770, 'cliente': 882, 'comision': 112},
    7500: {'asociado': 827, 'cliente': 962.50, 'comision': 135.50},
    8000: {'asociado': 886, 'cliente': 1006, 'comision': 120},
    9000: {'asociado': 996, 'cliente': 1131, 'comision': 135},
    10000: {'asociado': 1105, 'cliente': 1255, 'comision': 150},
    11000: {'asociado': 1220, 'cliente': 1385, 'comision': 165},
    12000: {'asociado': 1330, 'cliente': 1504, 'comision': 174},
    13000: {'asociado': 1440, 'cliente': 1634, 'comision': 194},
    14000: {'asociado': 1550, 'cliente': 1765, 'comision': 215},
    15000: {'asociado': 1660, 'cliente': 1888, 'comision': 228},
    16000: {'asociado': 1770, 'cliente': 2012, 'comision': 242},
    17000: {'asociado': 1880, 'cliente': 2137, 'comision': 257},
    18000: {'asociado': 1990, 'cliente': 2262, 'comision': 272},
    19000: {'asociado': 2100, 'cliente': 2386, 'comision': 286},
    20000: {'asociado': 2210, 'cliente': 2510, 'comision': 300},
    21000: {'asociado': 2320, 'cliente': 2640, 'comision': 320},
    22000: {'asociado': 2430, 'cliente': 2759, 'comision': 329},
    23000: {'asociado': 2540, 'cliente': 2889, 'comision': 349},
    24000: {'asociado': 2650, 'cliente': 3020, 'comision': 370},
    25000: {'asociado': 2760, 'cliente': 3143, 'comision': 383},
    26000: {'asociado': 2870, 'cliente': 3267, 'comision': 397},
    27000: {'asociado': 2980, 'cliente': 3392, 'comision': 412},
    28000: {'asociado': 3090, 'cliente': 3517, 'comision': 427},
    29000: {'asociado': 3200, 'cliente': 3641, 'comision': 441},
    30000: {'asociado': 3310, 'cliente': 3765, 'comision': 455},
}

print("=" * 100)
print("COMPARACIÓN: PDF (FUENTE DE VERDAD) vs BASE DE DATOS")
print("=" * 100)
print(f"{'Monto':>8} | {'PDF Asoc':>10} | {'DB Asoc':>10} | {'Diff Asoc':>12} | {'PDF Cli':>10} | {'DB Cli':>10} | {'Diff Cli':>12} | {'Estado':>10}")
print("-" * 100)

incorrectos_asociado = []
incorrectos_cliente = []
correctos = []
solo_db = []

# Comparar datos comunes
for monto in sorted(pdf_data.keys()):
    pdf = pdf_data[monto]
    
    if monto not in db_data:
        print(f"${monto:>7,} | ${pdf['asociado']:>9,} | {'FALTA':>10} | {'':>12} | ${pdf['cliente']:>9} | {'FALTA':>10} | {'':>12} | {'❌ FALTA':>10}")
        continue
    
    db = db_data[monto]
    
    diff_asociado = db['asociado'] - pdf['asociado']
    diff_cliente = db['cliente'] - pdf['cliente']
    
    # Determinar estado
    if diff_asociado == 0 and diff_cliente == 0:
        estado = "✅ OK"
        correctos.append(monto)
    elif diff_asociado != 0 and diff_cliente == 0:
        estado = "⚠️ ASOC"
        incorrectos_asociado.append(monto)
    elif diff_asociado == 0 and diff_cliente != 0:
        estado = "⚠️ CLI"
        incorrectos_cliente.append(monto)
    else:
        estado = "❌ AMBOS"
        incorrectos_asociado.append(monto)
        incorrectos_cliente.append(monto)
    
    print(f"${monto:>7,} | ${pdf['asociado']:>9,} | ${db['asociado']:>9,} | ${diff_asociado:>+11,} | ${pdf['cliente']:>9} | ${db['cliente']:>9} | ${diff_cliente:>+11} | {estado:>10}")

# Montos solo en DB
for monto in sorted(db_data.keys()):
    if monto not in pdf_data:
        db = db_data[monto]
        print(f"${monto:>7,} | {'NO PDF':>10} | ${db['asociado']:>9,} | {'':>12} | {'NO PDF':>10} | ${db['cliente']:>9} | {'':>12} | {'➕ EXTRA':>10}")
        solo_db.append(monto)

print("=" * 100)
print("\n📊 RESUMEN")
print("=" * 100)
print(f"✅ Correctos: {len(correctos)} montos")
print(f"⚠️  Incorrectos en ASOCIADO: {len(incorrectos_asociado)} montos")
print(f"⚠️  Incorrectos en CLIENTE: {len(incorrectos_cliente)} montos")
print(f"➕ Solo en DB (no en PDF): {len(solo_db)} montos")

if incorrectos_asociado:
    print(f"\n❌ Montos con ERROR en PAGO ASOCIADO:")
    for monto in incorrectos_asociado:
        pdf = pdf_data[monto]
        db = db_data[monto]
        diff = db['asociado'] - pdf['asociado']
        print(f"   ${monto:>7,}: DB=${db['asociado']:>6,} | PDF=${pdf['asociado']:>6,} | Diff=${diff:>+6,}")

if incorrectos_cliente:
    print(f"\n❌ Montos con ERROR en PAGO CLIENTE:")
    for monto in incorrectos_cliente:
        pdf = pdf_data[monto]
        db = db_data[monto]
        diff = db['cliente'] - pdf['cliente']
        print(f"   ${monto:>7,}: DB=${db['cliente']:>6} | PDF=${pdf['cliente']:>6} | Diff=${diff:>+6}")

if solo_db:
    print(f"\n➕ Montos EXTRA en DB (no en PDF):")
    for monto in solo_db:
        print(f"   ${monto:>7,}")

