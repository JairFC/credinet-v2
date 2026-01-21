import re

# Leer el texto del PDF
with open('docs/TABLA PRESTAMOS CREDICUENTA - CALCULO VALES.pdf', 'rb') as f:
    import subprocess
    text = subprocess.check_output(['pdftotext', '-', '-'], stdin=f).decode('utf-8')

# Buscar patrones de datos
lines = text.split('\n')

print("MONTO | PAGO_CLIENTE | PAGO_ASOCIADO | DIFERENCIA")
print("-" * 60)

# Parsear datos relevantes
i = 0
while i < len(lines):
    line = lines[i].strip()
    # Buscar monto que empiece con $
    if line.startswith('$') and ',' in line:
        # Extraer monto limpio
        monto = line.replace('$', '').replace(',', '')
        try:
            monto_val = float(monto)
            # Solo montos de préstamos (mayores a 1000)
            if monto_val >= 3000 and monto_val <= 30000:
                # Los siguientes valores deberían estar cerca
                pago_asociado = None
                pago_cliente = None
                
                # Buscar en las siguientes 15 líneas
                for j in range(1, 15):
                    if i + j < len(lines):
                        next_line = lines[i + j].strip()
                        if next_line.startswith('$') and ',' in next_line:
                            val = next_line.replace('$', '').replace(',', '')
                            try:
                                val_num = float(val)
                                if 300 <= val_num <= 4000:  # Rango de pagos quincenales
                                    if pago_asociado is None:
                                        pago_asociado = val_num
                                    elif pago_cliente is None:
                                        pago_cliente = val_num
                                        break
                            except:
                                pass
                
                if pago_asociado and pago_cliente:
                    diff = pago_cliente - pago_asociado
                    print(f"${monto_val:,.0f} | ${pago_asociado:,.2f} | ${pago_cliente:,.2f} | ${diff:,.2f}")
        except:
            pass
    i += 1

