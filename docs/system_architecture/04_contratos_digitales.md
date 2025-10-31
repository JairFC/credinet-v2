# Sistema de Contratos Digitales - Especificación Técnica

## 1. ARQUITECTURA DEL SISTEMA

### 1.1. Flujo de Generación de Contratos

```
Creación Préstamo → Validar Datos → Seleccionar Plantilla → Rellenar Variables → Generar PDF → Almacenar Documento → Registrar en BD
```

### 1.2. Componentes del Sistema

- **Generator Engine**: Motor de generación de contratos
- **Template Manager**: Gestor de plantillas
- **Variable Resolver**: Resolutor de variables dinámicas
- **PDF Engine**: Generador de documentos PDF
- **Document Storage**: Sistema de almacenamiento
- **Digital Signature**: Sistema de firmas digitales (futuro)

## 2. DISEÑO DE PLANTILLAS

### 2.1. Plantilla Base de Contrato

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Contrato de Préstamo - {{document_number}}</title>
    <style>
        body { 
            font-family: 'Times New Roman', serif; 
            font-size: 12px; 
            line-height: 1.4;
            margin: 40px;
        }
        .header { 
            text-align: center; 
            font-weight: bold; 
            font-size: 16px;
            margin-bottom: 30px;
        }
        .section { 
            margin: 20px 0; 
        }
        .loan-details { 
            background-color: #f9f9f9; 
            padding: 15px; 
            border: 1px solid #ddd;
            margin: 20px 0;
        }
        .signatures { 
            margin-top: 50px;
            display: flex;
            justify-content: space-between;
        }
        .signature-block {
            text-align: center;
            width: 45%;
        }
        .signature-line {
            border-bottom: 1px solid #000;
            margin-bottom: 5px;
            height: 50px;
        }
        .terms {
            font-size: 10px;
            text-align: justify;
            margin-top: 30px;
        }
    </style>
</head>
<body>
    <div class="header">
        CONTRATO DE PRÉSTAMO PERSONAL<br>
        No. {{document_number}}
    </div>

    <div class="section">
        <strong>ACREDITADO (CLIENTE):</strong><br>
        Nombre Completo: {{client_full_name}}<br>
        Dirección: {{client_address_complete}}<br>
        Teléfono: {{client_phone}}<br>
        CURP: {{client_curp}}<br>
        Correo Electrónico: {{client_email}}
    </div>

    <div class="section">
        <strong>ACREDITANTE:</strong><br>
        CrediCuenta S.A. de C.V.<br>
        RFC: CCSA123456ABC<br>
        Domicilio: [Dirección de la empresa]
    </div>

    {{#if associate_name}}
    <div class="section">
        <strong>ASOCIADO ORIGINADOR:</strong><br>
        {{associate_name}}<br>
        Comisión: {{commission_rate}}%<br>
        Contacto: {{associate_contact}}
    </div>
    {{/if}}

    <div class="loan-details">
        <strong>CARACTERÍSTICAS DEL PRÉSTAMO:</strong><br><br>
        <table style="width: 100%; border-collapse: collapse;">
            <tr>
                <td style="padding: 5px; border-bottom: 1px solid #ccc;"><strong>Monto del Préstamo:</strong></td>
                <td style="padding: 5px; border-bottom: 1px solid #ccc;">${{loan_amount_formatted}} MXN</td>
            </tr>
            <tr>
                <td style="padding: 5px; border-bottom: 1px solid #ccc;"><strong>Tasa de Interés:</strong></td>
                <td style="padding: 5px; border-bottom: 1px solid #ccc;">{{interest_rate}}% mensual</td>
            </tr>
            <tr>
                <td style="padding: 5px; border-bottom: 1px solid #ccc;"><strong>Plazo:</strong></td>
                <td style="padding: 5px; border-bottom: 1px solid #ccc;">{{term_months}} meses</td>
            </tr>
            <tr>
                <td style="padding: 5px; border-bottom: 1px solid #ccc;"><strong>Plazo:</strong></td>
                <td style="padding: 5px; border-bottom: 1px solid #ccc;">{{term_biweeks}} quincenas (solo quincenal)</td>
            </tr>
            <tr>
                <td style="padding: 5px; border-bottom: 1px solid #ccc;"><strong>Pago Periódico:</strong></td>
                <td style="padding: 5px; border-bottom: 1px solid #ccc;">${{monthly_payment_formatted}} MXN</td>
            </tr>
            <tr>
                <td style="padding: 5px;"><strong>Total a Pagar:</strong></td>
                <td style="padding: 5px;"><strong>${{total_amount_formatted}} MXN</strong></td>
            </tr>
        </table>
    </div>

    <div class="section">
        <strong>FECHAS IMPORTANTES:</strong><br>
        Fecha de Inicio del Préstamo: {{start_date_formatted}}<br>
        Primera Fecha de Pago: {{first_payment_date}}<br>
        Última Fecha de Pago: {{last_payment_date}}
    </div>

    <div class="section">
        <strong>OBLIGACIONES DEL ACREDITADO:</strong><br>
        1. Pagar puntualmente las cantidades especificadas en las fechas acordadas.<br>
        2. Mantener actualizada su información de contacto.<br>
        3. Notificar cualquier cambio en su situación financiera.<br>
        4. Cumplir con todas las disposiciones del presente contrato.
    </div>

    <div class="section">
        <strong>TABLA DE AMORTIZACIÓN:</strong><br>
        El desglose detallado de pagos se encuentra en el anexo adjunto a este contrato.
    </div>

    <div class="signatures">
        <div class="signature-block">
            <div class="signature-line"></div>
            <strong>{{client_full_name}}</strong><br>
            ACREDITADO<br>
            Fecha: {{sign_date_formatted}}
        </div>
        
        <div class="signature-block">
            <div class="signature-line"></div>
            <strong>CrediCuenta S.A. de C.V.</strong><br>
            ACREDITANTE<br>
            Fecha: {{sign_date_formatted}}
        </div>
    </div>

    <div class="terms">
        <strong>TÉRMINOS Y CONDICIONES:</strong><br>
        El presente contrato se rige por las leyes mexicanas aplicables. 
        Cualquier controversia será resuelta en los tribunales competentes de [Ciudad].
        El incumplimiento en el pago generará intereses moratorios del 2% mensual.
        El acreditado acepta todos los términos y condiciones establecidos en este documento.
    </div>

    <div style="margin-top: 30px; text-align: center; font-size: 10px; color: #666;">
        Documento generado automáticamente el {{generation_date_formatted}}<br>
        ID de Transacción: {{transaction_id}}
    </div>
</body>
</html>
```

### 2.2. Variables Dinámicas del Sistema

#### Variables del Cliente
```python
CLIENT_VARIABLES = {
    'client_full_name': 'user.first_name + " " + user.last_name',
    'client_phone': 'user.phone_number',
    'client_email': 'user.email',
    'client_curp': 'user.curp',
    'client_address_complete': 'address.street + " " + address.external_number + ...',
}
```

#### Variables del Préstamo
```python
LOAN_VARIABLES = {
    'loan_amount': 'loan.amount',
    'loan_amount_formatted': 'format_currency(loan.amount)',
    'interest_rate': 'loan.interest_rate',
    'term_months': 'loan.term_months',
    'monthly_payment': 'calculated_monthly_payment',
    'monthly_payment_formatted': 'format_currency(calculated_monthly_payment)',
    'total_amount': 'calculated_total_amount',
    'total_amount_formatted': 'format_currency(calculated_total_amount)',
}
```

#### Variables del Asociado
```python
ASSOCIATE_VARIABLES = {
    'associate_name': 'associate_user.first_name + " " + associate_user.last_name',
    'associate_contact': 'associate_profile.contact_email',
    'commission_rate': 'loan.commission_rate',
}
```

#### Variables del Contrato
```python
CONTRACT_VARIABLES = {
    'document_number': 'auto_generated_document_number',
    'start_date_formatted': 'format_date(contract.start_date)',
    'sign_date_formatted': 'format_date(contract.sign_date)',
    'first_payment_date': 'calculated_first_payment_date',
    'last_payment_date': 'calculated_last_payment_date',
    'generation_date_formatted': 'format_datetime(now())',
    'transaction_id': 'contract.id + "-" + loan.id',
}
```

## 3. MOTOR DE GENERACIÓN

### 3.1. Clase ContractGenerator

```python
class ContractGenerator:
    def __init__(self):
        self.template_engine = TemplateEngine()
        self.pdf_generator = PDFGenerator()
        self.variable_resolver = VariableResolver()
    
    async def generate_contract(self, loan_id: int, template_id: int = None):
        """Genera un contrato completo para un préstamo"""
        
        # 1. Obtener datos del préstamo
        loan_data = await self.get_loan_complete_data(loan_id)
        
        # 2. Seleccionar plantilla
        template = await self.get_template(template_id or self.get_default_template_id())
        
        # 3. Resolver variables
        variables = await self.variable_resolver.resolve_all_variables(loan_data)
        
        # 4. Generar HTML
        html_content = self.template_engine.render(template.content, variables)
        
        # 5. Generar PDF
        pdf_content = await self.pdf_generator.html_to_pdf(html_content)
        
        # 6. Almacenar documento
        document_path = await self.store_document(pdf_content, loan_id)
        
        # 7. Crear registro en BD
        contract_id = await self.create_contract_record(loan_id, document_path, variables)
        
        return contract_id, document_path
```

### 3.2. Generación Automática de Número de Contrato

```python
async def generate_document_number(self, year: int = None) -> str:
    """Genera número único de contrato formato: CONT-2025-001234"""
    current_year = year or datetime.now().year
    
    # Obtener el siguiente número secuencial para el año
    next_number = await self.get_next_contract_number(current_year)
    
    return f"CONT-{current_year}-{next_number:06d}"
```

## 4. SISTEMA DE ALMACENAMIENTO

### 4.1. Estructura de Directorios

```
/uploads/documents/contracts/
├── 2025/
│   ├── 01/  # Enero
│   │   ├── CONT-2025-000001.pdf
│   │   ├── CONT-2025-000002.pdf
│   │   └── ...
│   ├── 02/  # Febrero
│   └── ...
└── templates/
    ├── contract_standard_v1.html
    ├── contract_premium_v1.html
    └── ...
```

### 4.2. Función de Almacenamiento

```python
async def store_contract_document(self, pdf_content: bytes, loan_id: int, document_number: str) -> str:
    """Almacena el documento PDF del contrato en el sistema de archivos"""
    
    # Crear estructura de directorios por año/mes
    now = datetime.now()
    directory = f"/uploads/documents/contracts/{now.year}/{now.month:02d}"
    os.makedirs(directory, exist_ok=True)
    
    # Generar nombre de archivo
    filename = f"{document_number}.pdf"
    file_path = os.path.join(directory, filename)
    
    # Guardar archivo
    with open(file_path, 'wb') as f:
        f.write(pdf_content)
    
    # Registrar en tabla de documentos del cliente
    await self.register_client_document(loan_id, file_path, 'Contrato de Préstamo')
    
    return file_path
```

## 5. INTEGRACIÓN CON SISTEMA DE DOCUMENTOS

### 5.1. Registro Automático en client_documents

```python
async def register_client_document(self, loan_id: int, file_path: str, document_type: str):
    """Registra automáticamente el contrato en los documentos del cliente"""
    
    # Obtener client_id del préstamo
    loan = await self.get_loan(loan_id)
    client_id = loan.user_id
    
    # Obtener document_type_id
    doc_type = await self.get_document_type_by_name('Contrato de Préstamo')
    
    # Crear registro
    await self.create_client_document({
        'client_id': client_id,
        'document_type_id': doc_type.id,
        'file_name': os.path.basename(file_path),
        'original_file_name': f"Contrato_{loan_id}.pdf",
        'file_path': file_path,
        'status': 'APPROVED',  # Contratos generados automáticamente son pre-aprobados
        'upload_date': datetime.now(),
        'comments': f'Contrato generado automáticamente para préstamo ID: {loan_id}'
    })
```

## 6. API ENDPOINTS PARA CONTRATOS

### 6.1. Generar Contrato

```python
@router.post("/loans/{loan_id}/contract/generate")
async def generate_loan_contract(
    loan_id: int,
    template_id: Optional[int] = None,
    current_user: UserInDB = Depends(require_roles(["administrador", "auxiliar_administrativo"])),
    conn: asyncpg.Connection = Depends(get_db)
):
    """Genera un contrato para un préstamo específico"""
    
    generator = ContractGenerator()
    contract_id, document_path = await generator.generate_contract(loan_id, template_id)
    
    return {
        "contract_id": contract_id,
        "document_path": document_path,
        "message": "Contrato generado exitosamente"
    }
```

### 6.2. Descargar Contrato

```python
@router.get("/contracts/{contract_id}/download")
async def download_contract(
    contract_id: int,
    current_user: UserInDB = Depends(get_current_user),
    conn: asyncpg.Connection = Depends(get_db)
):
    """Descarga el PDF del contrato"""
    
    contract = await get_contract_by_id(conn, contract_id)
    
    # Verificar permisos
    if not await user_can_access_contract(current_user, contract):
        raise HTTPException(status_code=403, detail="Sin permisos para acceder a este contrato")
    
    return FileResponse(
        path=contract.file_path,
        filename=f"Contrato_{contract.document_number}.pdf",
        media_type='application/pdf'
    )
```

## 7. FUNCIONES AUXILIARES

### 7.1. Formateadores de Datos

```python
def format_currency(amount: float) -> str:
    """Formatea cantidad como moneda mexicana"""
    return f"{amount:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")

def format_date(date: datetime.date) -> str:
    """Formatea fecha en español"""
    months = [
        "enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
    ]
    return f"{date.day} de {months[date.month-1]} de {date.year}"

def format_term_biweeks(term_biweeks: int) -> str:
    """Convierte número de quincenas a texto legible"""
    return f"{term_biweeks} quincenas (sistema solo quincenal)"
```

## 8. FLUJO DE IMPLEMENTACIÓN

### 8.1. Fase 1: Estructura Base
1. Crear tablas de plantillas y configuración
2. Implementar motor básico de generación
3. Crear plantilla estándar de contrato

### 8.2. Fase 2: Generación Automática
1. Integrar generación en endpoint de creación de préstamos
2. Implementar almacenamiento de documentos
3. Crear APIs de descarga y visualización

### 8.3. Fase 3: Funcionalidades Avanzadas
1. Sistema de plantillas múltiples
2. Firmas digitales
3. Versioning de contratos
4. Notificaciones automáticas

Este sistema proporcionará una base sólida para la generación automática de contratos digitales, manteniendo la flexibilidad para futuras mejoras y la integración completa con el ecosistema existente de Credinet.