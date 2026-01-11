#!/usr/bin/env python3
import subprocess
import re

# Extraer texto del PDF
with open('docs/TABLA PRESTAMOS CREDICUENTA - CALCULO VALES.pdf', 'rb') as f:
    text = subprocess.check_output(['pdftotext', '-layout', '-', '-'], stdin=f).decode('utf-8', errors='ignore')

# Encontrar todas las líneas con datos relevantes
lines = text.split('\n')

# Buscar el patrón: hay dos bloques por monto (uno con 12 quincenas, otro resumen)
data = {}
current_monto = None

for i, line in enumerate(lines):
    # Buscar líneas que empiezan con $ y tienen coma (montos de préstamo)
    match = re.search(r'\$(\d{1,2}),(\d{3})', line)
    if match:
        monto_str = match.group(1) + match.group(2)
        monto = int(monto_str)
        
        # Solo nos interesan los montos de préstamo (3,000 a 30,000)
        if 3000 <= monto <= 30000:
            # Buscar el pago asociado y el pago del cliente en las líneas cercanas
            # El patrón es: MONTO luego PAGO_ASOCIADO luego...
            for j in range(1, 10):
                if i + j < len(lines):
                    next_line = lines[i + j]
                    # Buscar pagos (montos entre $300 y $4,000)
                    payment_match = re.search(r'\$(\d{1}),?(\d{3})', next_line)
                    if payment_match:
                        payment_str = payment_match.group(1) + payment_match.group(2)
                        payment = int(payment_str)
                        
                        if 300 <= payment <= 4000:
                            if monto not in data:
                                data[monto] = {'asociado': payment, 'cliente': None}
                            elif data[monto]['cliente'] is None:
                                data[monto]['cliente'] = payment
                                break

# Imprimir resultados organizados
print("=" * 80)
print("DATOS DEL PDF - TABLA PRESTAMOS CREDICUENTA")
print("=" * 80)
print(f"{'Monto':>10} | {'Pago Asociado':>15} | {'Pago Cliente':>15} | {'Comisión':>12}")
print("-" * 80)

for monto in sorted(data.keys()):
    if data[monto]['asociado'] and data[monto]['cliente']:
        asociado = data[monto]['asociado']
        cliente = data[monto]['cliente']
        comision = cliente - asociado
        print(f"${monto:>8,} | ${asociado:>13,} | ${cliente:>13,} | ${comision:>10,}")

