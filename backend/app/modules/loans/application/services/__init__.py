"""
Servicio de aplicación para préstamos (loans).

Este servicio encapsula la lógica de negocio para:
- Crear solicitudes de préstamo
- Aprobar préstamos (con validaciones críticas)
- Rechazar préstamos
- Validaciones pre-aprobación

⭐ CRÍTICO: Validaciones de negocio para garantizar integridad
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.loans.domain.entities import (
    Loan,
    LoanStatusEnum,
    LoanApprovalRequest,
    LoanRejectionRequest,
)
from app.modules.loans.domain.repositories import LoanRepository
from app.modules.loans.infrastructure.repositories import PostgreSQLLoanRepository
from app.modules.loans.application.logger import (
    log_loan_created,
    log_loan_approved,
    log_loan_rejected,
    log_loan_updated,
    log_loan_cancelled,
    log_validation_error,
)
from app.core.notifications import notify


class LoanService:
    """
    Servicio de aplicación para préstamos.
    
    Responsabilidades:
    - Coordinar operaciones entre repositorio y entidades
    - Aplicar reglas de negocio
    - Validaciones pre-aprobación
    - Gestión de transacciones
    """
    
    def __init__(self, session: AsyncSession):
        """
        Constructor.
        
        Args:
            session: Sesión asíncrona de SQLAlchemy
        """
        self.session = session
        self.repository: LoanRepository = PostgreSQLLoanRepository(session)
    
    # =============================================================================
    # CREAR SOLICITUD DE PRÉSTAMO
    # =============================================================================
    
    async def create_loan_request(
        self,
        user_id: int,
        associate_user_id: int,
        amount: Decimal,
        term_biweeks: int,
        profile_code: Optional[str] = None,
        interest_rate: Optional[Decimal] = None,
        commission_rate: Optional[Decimal] = None,
        notes: Optional[str] = None
    ) -> Loan:
        """
        Crea una nueva solicitud de préstamo.
        
        Opciones de tasas:
        1. Con profile_code: Las tasas se calculan automáticamente usando rate_profiles
        2. Sin profile_code: Tasas manuales (interest_rate y commission_rate son obligatorias)
        
        Validaciones iniciales:
        1. Si usa profile_code, calcular tasas automáticamente
        2. Si no usa profile_code, validar que tasas manuales estén presentes
        3. El asociado tiene crédito disponible suficiente
        4. El cliente no tiene otros préstamos PENDING
        5. El cliente no es moroso
        
        Args:
            user_id: ID del cliente solicitante
            associate_user_id: ID del asociado que otorga el préstamo
            amount: Monto solicitado
            term_biweeks: Plazo en quincenas
            profile_code: Código del perfil de tasa (opcional)
            interest_rate: Tasa de interés manual (%) - requerida si no hay profile_code
            commission_rate: Tasa de comisión manual (%) - requerida si no hay profile_code
            notes: Notas adicionales (opcional)
            
        Returns:
            Loan creado con status PENDING
            
        Raises:
            ValueError: Si alguna validación falla
        """
        # Validación 0: Determinar tasas (automáticas o manuales)
        # Variables para guardar valores calculados
        calculated_values = None
        
        if profile_code and profile_code != 'custom':
            # Opción 1: Calcular tasas usando perfil predefinido (legacy, standard, etc.)
            # Usar SQL directo para calcular (evitar importar RateProfileService por ahora)
            from sqlalchemy import text
            
            print(f"🔍 DEBUG: Calculando con perfil '{profile_code}'")
            
            try:
                # Llamar a la función SQL directamente
                query = text("""
                    SELECT 
                        profile_code,
                        profile_name,
                        calculation_method,
                        interest_rate_percent,
                        commission_rate_percent,
                        biweekly_payment,
                        total_payment,
                        total_interest,
                        effective_rate_percent,
                        commission_per_payment,
                        total_commission,
                        associate_payment,
                        associate_total
                    FROM calculate_loan_payment(:amount, :term_biweeks, :profile_code)
                """)
                
                result = await self.session.execute(
                    query,
                    {"amount": amount, "term_biweeks": term_biweeks, "profile_code": profile_code}
                )
                
                row = result.fetchone()
                
                print(f"🔍 DEBUG: Resultado de calculate_loan_payment:")
                print(f"  row: {row}")
                
                if not row:
                    raise ValueError(f"No se pudo calcular préstamo con perfil '{profile_code}'")
                
                # Guardar todos los valores calculados
                calculated_values = {
                    'biweekly_payment': Decimal(str(row.biweekly_payment)),
                    'total_payment': Decimal(str(row.total_payment)),
                    'total_interest': Decimal(str(row.total_interest)),
                    'total_commission': Decimal(str(row.total_commission)),
                    'commission_per_payment': Decimal(str(row.commission_per_payment)),
                    'associate_payment': Decimal(str(row.associate_payment)),
                }
                
                # Usar las tasas calculadas
                final_interest_rate = row.interest_rate_percent
                final_commission_rate = row.commission_rate_percent
                
                print(f"🔍 DEBUG: Tasas calculadas:")
                print(f"  final_interest_rate: {final_interest_rate}")
                print(f"  final_commission_rate: {final_commission_rate}")
                
            except Exception as e:
                print(f"❌ ERROR en calculate_loan_payment: {e}")
                import traceback
                traceback.print_exc()
                raise ValueError(f"Error al calcular tasas con perfil '{profile_code}': {e}")
        
        elif profile_code == 'custom':
            # Opción 2: Perfil 'custom' con tasas manuales
            from sqlalchemy import text
            
            if interest_rate is None or commission_rate is None:
                raise ValueError(
                    "Para perfil 'custom' se requieren interest_rate y commission_rate"
                )
            
            print(f"🔍 DEBUG: Calculando con perfil 'custom', interest_rate={interest_rate}, commission_rate={commission_rate}")
            
            try:
                # Usar la función SQL para custom
                query = text("""
                    SELECT 
                        profile_code,
                        profile_name,
                        calculation_method,
                        interest_rate_percent,
                        commission_rate_percent,
                        biweekly_payment,
                        total_payment,
                        total_interest,
                        effective_rate_percent,
                        commission_per_payment,
                        total_commission,
                        associate_payment,
                        associate_total
                    FROM calculate_loan_payment_custom(:amount, :term_biweeks, :interest_rate, :commission_rate)
                """)
                
                result = await self.session.execute(
                    query,
                    {
                        "amount": amount, 
                        "term_biweeks": term_biweeks, 
                        "interest_rate": float(interest_rate),
                        "commission_rate": float(commission_rate)
                    }
                )
                
                row = result.fetchone()
                
                if not row:
                    raise ValueError("No se pudo calcular préstamo con perfil 'custom'")
                
                # Guardar todos los valores calculados
                calculated_values = {
                    'biweekly_payment': Decimal(str(row.biweekly_payment)),
                    'total_payment': Decimal(str(row.total_payment)),
                    'total_interest': Decimal(str(row.total_interest)),
                    'total_commission': Decimal(str(row.total_commission)),
                    'commission_per_payment': Decimal(str(row.commission_per_payment)),
                    'associate_payment': Decimal(str(row.associate_payment)),
                }
                
                # Usar las tasas del request
                final_interest_rate = interest_rate
                final_commission_rate = commission_rate
                
                print(f"🔍 DEBUG: Resultado de calculate_loan_payment_custom:")
                print(f"  biweekly_payment: {calculated_values['biweekly_payment']}")
                print(f"  commission_per_payment: {calculated_values['commission_per_payment']}")
                
            except Exception as e:
                print(f"❌ ERROR en calculate_loan_payment_custom: {e}")
                import traceback
                traceback.print_exc()
                raise ValueError(f"Error al calcular préstamo custom: {e}")
        
        else:
            # Opción 3: Sin profile_code, usar tasas manuales con cálculo local
            if interest_rate is None or commission_rate is None:
                raise ValueError(
                    "Si no se proporciona profile_code, interest_rate y commission_rate son obligatorias"
                )
            
            final_interest_rate = interest_rate
            final_commission_rate = commission_rate
            
            # Calcular valores manualmente usando la misma fórmula que la BD (interés simple)
            # Formula: total = amount * (1 + (interest_rate / 100) * term_biweeks)
            factor = Decimal('1') + (interest_rate / Decimal('100')) * Decimal(str(term_biweeks))
            total_payment = amount * factor
            biweekly_payment = total_payment / Decimal(str(term_biweeks))
            total_interest = total_payment - amount
            
            # Calcular comisiones
            commission_per_payment = biweekly_payment * (commission_rate / Decimal('100'))
            total_commission = commission_per_payment * Decimal(str(term_biweeks))
            associate_payment = biweekly_payment - commission_per_payment
            
            calculated_values = {
                'biweekly_payment': biweekly_payment.quantize(Decimal('0.01')),
                'total_payment': total_payment.quantize(Decimal('0.01')),
                'total_interest': total_interest.quantize(Decimal('0.01')),
                'total_commission': total_commission.quantize(Decimal('0.01')),
                'commission_per_payment': commission_per_payment.quantize(Decimal('0.01')),
                'associate_payment': associate_payment.quantize(Decimal('0.01')),
            }
            
            print(f"🔍 DEBUG: Valores calculados manualmente (sin perfil):")
            print(f"  biweekly_payment: {calculated_values['biweekly_payment']}")
            print(f"  total_payment: {calculated_values['total_payment']}")
        
        # Validación 1: Crédito del asociado
        print(f"🔍 DEBUG: Validación 1 - Verificando crédito del asociado {associate_user_id}")
        has_credit = await self.repository.check_associate_available_credit(
            associate_user_id, amount
        )
        print(f"🔍 DEBUG: has_credit = {has_credit}")
        if not has_credit:
            raise ValueError(
                f"El asociado {associate_user_id} no tiene crédito disponible "
                f"suficiente para otorgar ${amount}"
            )
        
        # Validación 2: Cliente no tiene préstamos PENDING
        print(f"🔍 DEBUG: Validación 2 - Verificando préstamos PENDING del cliente {user_id}")
        has_pending = await self.repository.has_pending_loans(user_id)
        print(f"🔍 DEBUG: has_pending = {has_pending}")
        if has_pending:
            raise ValueError(
                f"El cliente {user_id} ya tiene préstamos pendientes de aprobación. "
                f"Por favor, espere a que se procesen antes de solicitar otro."
            )
        
        # Validación 3: Cliente no es moroso
        print(f"🔍 DEBUG: Validación 3 - Verificando morosidad del cliente {user_id}")
        is_defaulter = await self.repository.is_client_defaulter(user_id)
        print(f"🔍 DEBUG: is_defaulter = {is_defaulter}")
        if is_defaulter:
            raise ValueError(
                f"El cliente {user_id} está marcado como moroso. "
                f"No puede solicitar nuevos préstamos hasta regularizar su situación."
            )
        
        # Crear entidad Loan (status PENDING por default)
        # Si no hay profile_code (tasas manuales), asignar 'custom'
        final_profile_code = profile_code if profile_code else 'custom'
        
        loan = Loan(
            id=None,  # Se asigna en BD
            user_id=user_id,
            associate_user_id=associate_user_id,
            amount=amount,
            interest_rate=final_interest_rate,
            commission_rate=final_commission_rate,
            term_biweeks=term_biweeks,
            status_id=LoanStatusEnum.PENDING.value,
            contract_id=None,  # Se asigna después si hay contrato
            profile_code=final_profile_code,  # Guardar 'custom' si no hay perfil específico
            # Campos calculados (solo si se usó profile_code)
            biweekly_payment=calculated_values['biweekly_payment'] if calculated_values else None,
            total_payment=calculated_values['total_payment'] if calculated_values else None,
            total_interest=calculated_values['total_interest'] if calculated_values else None,
            total_commission=calculated_values['total_commission'] if calculated_values else None,
            commission_per_payment=calculated_values['commission_per_payment'] if calculated_values else None,
            associate_payment=calculated_values['associate_payment'] if calculated_values else None,
            # Estado y tracking
            approved_at=None,
            approved_by=None,
            rejected_at=None,
            rejected_by=None,
            rejection_reason=None,
            notes=notes,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        
        # Guardar en BD
        created_loan = await self.repository.create(loan)
        
        return created_loan
    
    # =============================================================================
    # APROBAR PRÉSTAMO ⭐ CRÍTICO
    # =============================================================================
    
    async def approve_loan(
        self,
        loan_id: int,
        approved_by: int,
        notes: Optional[str] = None
    ) -> Loan:
        """
        Aprueba un préstamo.
        
        ⭐ CRÍTICO: Este método ejecuta las validaciones más importantes del sistema.
        
        Proceso:
        1. Buscar préstamo por ID
        2. Validar que esté en estado PENDING
        3. Validar pre-aprobación (crédito, morosidad, documentos)
        4. Calcular fecha del primer pago (función DB: calculate_first_payment_date)
        5. Actualizar préstamo a ACTIVE (antes APPROVED, ahora unificado)
        6. Trigger genera cronograma de pagos automáticamente
        7. Actualizar pending_payments_total del asociado (transacción ACID)
        
        Args:
            loan_id: ID del préstamo a aprobar
            approved_by: ID del usuario que aprueba
            notes: Notas adicionales (opcional)
            
        Returns:
            Loan aprobado
            
        Raises:
            ValueError: Si alguna validación falla
        """
        # 1. Buscar préstamo
        loan = await self.repository.find_by_id(loan_id)
        if not loan:
            raise ValueError(f"Préstamo con ID {loan_id} no encontrado")
        
        # 2. Validar que esté PENDING
        if not loan.is_pending():
            raise ValueError(
                f"El préstamo {loan_id} no está en estado PENDING. "
                f"Estado actual: {loan.status_id}"
            )
        
        # 3. Validar que puede ser aprobado (validaciones de entidad)
        if not loan.can_be_approved():
            raise ValueError(
                f"El préstamo {loan_id} no puede ser aprobado. "
                f"Verifique que no esté rechazado o cancelado."
            )
        
        # 4. Validaciones pre-aprobación
        await self._validate_pre_approval(loan)
        
        # 5. Calcular fecha del primer pago (⭐ FUNCIÓN DB - DOBLE CALENDARIO)
        approval_date = datetime.utcnow().date()
        first_payment_date = await self.repository.calculate_first_payment_date(
            approval_date
        )
        
        # 6. CRÍTICO: Asegurar que los campos calculados existan
        # Si biweekly_payment es NULL, recalcular usando profile_code o tasas manuales
        if loan.biweekly_payment is None:
            print(f"⚠️  WARN: Préstamo {loan_id} no tiene biweekly_payment. Recalculando...")
            
            if loan.profile_code:
                # Recalcular usando perfil
                from sqlalchemy import text
                
                try:
                    query = text("""
                        SELECT 
                            biweekly_payment,
                            total_payment,
                            total_interest,
                            total_commission,
                            commission_per_payment,
                            associate_payment
                        FROM calculate_loan_payment(:amount, :term_biweeks, :profile_code)
                    """)
                    
                    result = await self.session.execute(
                        query,
                        {
                            "amount": loan.amount,
                            "term_biweeks": loan.term_biweeks,
                            "profile_code": loan.profile_code
                        }
                    )
                    
                    row = result.fetchone()
                    
                    if row:
                        loan.biweekly_payment = Decimal(str(row.biweekly_payment))
                        loan.total_payment = Decimal(str(row.total_payment))
                        loan.total_interest = Decimal(str(row.total_interest))
                        loan.total_commission = Decimal(str(row.total_commission))
                        loan.commission_per_payment = Decimal(str(row.commission_per_payment))
                        loan.associate_payment = Decimal(str(row.associate_payment))
                        
                        print(f"✅ Valores recalculados con perfil '{loan.profile_code}'")
                        print(f"   - biweekly_payment: {loan.biweekly_payment}")
                        print(f"   - total_payment: {loan.total_payment}")
                    else:
                        raise ValueError(f"No se pudo recalcular valores con perfil '{loan.profile_code}'")
                        
                except Exception as e:
                    print(f"❌ ERROR recalculando valores: {e}")
                    raise ValueError(f"Error al recalcular valores del préstamo: {e}")
            else:
                # Sin profile_code, calcular manualmente con generate_loan_summary
                from sqlalchemy import text
                
                try:
                    query = text("""
                        SELECT 
                            pago_quincenal_cliente,
                            pago_total_cliente,
                            interes_total_cliente,
                            tasa_efectiva_cliente,
                            comision_por_pago,
                            comision_total_socio,
                            pago_quincenal_socio,
                            pago_total_socio
                        FROM generate_loan_summary(
                            :amount,
                            :term_biweeks,
                            :interest_rate,
                            :commission_rate
                        )
                    """)
                    
                    result = await self.session.execute(
                        query,
                        {
                            "amount": loan.amount,
                            "term_biweeks": loan.term_biweeks,
                            "interest_rate": loan.interest_rate,
                            "commission_rate": loan.commission_rate
                        }
                    )
                    
                    row = result.fetchone()
                    
                    if row:
                        loan.biweekly_payment = Decimal(str(row.pago_quincenal_cliente))
                        loan.total_payment = Decimal(str(row.pago_total_cliente))
                        loan.total_interest = Decimal(str(row.interes_total_cliente))
                        loan.total_commission = Decimal(str(row.comision_total_socio))
                        loan.commission_per_payment = Decimal(str(row.comision_por_pago))
                        loan.associate_payment = Decimal(str(row.pago_quincenal_socio))
                        
                        print(f"✅ Valores recalculados con tasas manuales")
                        print(f"   - interest_rate: {loan.interest_rate}%")
                        print(f"   - commission_rate: {loan.commission_rate}%")
                        print(f"   - biweekly_payment: {loan.biweekly_payment}")
                    else:
                        raise ValueError("No se pudo calcular valores con generate_loan_summary")
                        
                except Exception as e:
                    print(f"❌ ERROR calculando valores: {e}")
                    raise ValueError(f"Error al calcular valores del préstamo: {e}")
        else:
            print(f"✅ Préstamo {loan_id} ya tiene valores calculados:")
            print(f"   - biweekly_payment: {loan.biweekly_payment}")
            print(f"   - total_payment: {loan.total_payment}")
            print(f"   - commission_per_payment: {loan.commission_per_payment}")
        
        # 7. Actualizar préstamo a ACTIVE (antes era APPROVED, ahora unificado)
        loan.status_id = LoanStatusEnum.ACTIVE.value
        loan.approved_at = datetime.utcnow()
        loan.approved_by = approved_by
        if notes:
            loan.notes = f"{loan.notes}\n[APROBACIÓN] {notes}" if loan.notes else f"[APROBACIÓN] {notes}"
        
        # 8. Guardar (transacción ACID)
        # NOTA: El trigger generate_payment_schedule() se ejecuta automáticamente
        # cuando status_id cambia a ACTIVE (2)
        approved_loan = await self.repository.update(loan)
        
        # 8. Commit de la transacción (incluye trigger)
        await self.session.commit()
        
        # Log de auditoría
        log_loan_approved(
            loan_id=loan_id,
            user_id=loan.user_id,
            associate_user_id=loan.associate_user_id,
            amount=float(loan.amount),
            first_payment_date=str(first_payment_date)
        )
        
        # 🔔 Notificación de préstamo aprobado
        try:
            # Obtener nombres del asociado y cliente para la notificación
            from sqlalchemy import text
            result = await self.session.execute(
                text("""
                    SELECT 
                        (SELECT first_name || ' ' || last_name FROM users WHERE id = :associate_id) AS associate_name,
                        (SELECT first_name || ' ' || last_name FROM clients WHERE id = :client_id) AS client_name
                """),
                {"associate_id": loan.associate_user_id, "client_id": loan.user_id}
            )
            names = result.fetchone()
            associate_name = names[0] or f"ID #{loan.associate_user_id}" if names else f"ID #{loan.associate_user_id}"
            client_name = names[1] or f"ID #{loan.user_id}" if names else f"ID #{loan.user_id}"
            
            # Calcular fecha aproximada de finalización
            from datetime import timedelta
            end_date = first_payment_date + timedelta(days=(loan.term_biweeks - 1) * 15)
            
            # Construir mensaje de notificación
            msg_parts = [
                f"• ID: #{loan_id}",
                f"• Cliente: {client_name}",
                f"• Asociado: {associate_name}",
                f"• Monto: ${loan.amount:,.2f}",
                f"• Plazo: {loan.term_biweeks} quincenas",
                f"• Pago quincenal: ${loan.biweekly_payment:,.2f}",
                f"• Fecha finalización: {end_date.strftime('%d/%m/%Y')}"
            ]
            if notes:
                msg_parts.append(f"• Notas: {notes}")
            
            await notify.send(
                title="Préstamo Aprobado",
                message="\n".join(msg_parts),
                level="success"
            )
        except Exception as e:
            print(f"⚠️ Error enviando notificación: {e}")
        
        return approved_loan
    
    async def _validate_pre_approval(self, loan: Loan) -> None:
        """
        Valida que el préstamo cumple con los requisitos para ser aprobado.
        
        Validaciones:
        1. Crédito del asociado disponible (puede haber cambiado desde creación)
        2. Cliente no es moroso
        3. Cliente no tiene préstamos PENDING (además del actual)
        
        TODO Sprint 3: Agregar validación de documentos completos
        
        Args:
            loan: Préstamo a validar
            
        Raises:
            ValueError: Si alguna validación falla
        """
        # Validación 1: Crédito del asociado
        has_credit = await self.repository.check_associate_available_credit(
            loan.associate_user_id, loan.amount
        )
        if not has_credit:
            raise ValueError(
                f"El asociado {loan.associate_user_id} ya no tiene crédito disponible "
                f"suficiente para otorgar ${loan.amount}. "
                f"Es posible que haya otorgado otros préstamos mientras tanto."
            )
        
        # Validación 2: Cliente no es moroso
        is_defaulter = await self.repository.is_client_defaulter(loan.user_id)
        if is_defaulter:
            raise ValueError(
                f"El cliente {loan.user_id} está marcado como moroso. "
                f"No se puede aprobar el préstamo hasta que regularice su situación."
            )
        
        # Validación 3: No tiene otros préstamos PENDING
        # (Verificar que solo tenga este préstamo PENDING)
        count_pending = await self._count_pending_loans_except(loan.user_id, loan.id)
        if count_pending > 0:
            raise ValueError(
                f"El cliente {loan.user_id} tiene {count_pending} préstamos PENDING adicionales. "
                f"Por favor, procese o cancele esos préstamos antes de aprobar este."
            )
        
        # TODO Sprint 3: Validación 4 - Documentos completos
        # has_documents = await self._check_required_documents(loan.user_id)
        # if not has_documents:
        #     raise ValueError(
        #         f"El cliente {loan.user_id} no tiene los documentos requeridos completos"
        #     )
    
    async def _count_pending_loans_except(self, user_id: int, exclude_loan_id: int) -> int:
        """
        Cuenta préstamos PENDING del cliente, excluyendo el préstamo actual.
        
        Args:
            user_id: ID del cliente
            exclude_loan_id: ID del préstamo a excluir
            
        Returns:
            Cantidad de préstamos PENDING (sin contar el excluido)
        """
        total_count = await self.repository.count(
            status_id=LoanStatusEnum.PENDING.value,
            user_id=user_id
        )
        
        # Si encontramos el préstamo actual, restar 1
        loan = await self.repository.find_by_id(exclude_loan_id)
        if loan and loan.is_pending():
            return total_count - 1
        
        return total_count
    
    # =============================================================================
    # RECHAZAR PRÉSTAMO
    # =============================================================================
    
    async def reject_loan(
        self,
        loan_id: int,
        rejected_by: int,
        rejection_reason: str
    ) -> Loan:
        """
        Rechaza un préstamo.
        
        Proceso:
        1. Buscar préstamo por ID
        2. Validar que esté en estado PENDING
        3. Actualizar préstamo a REJECTED
        4. Liberar crédito del asociado (no se consumió)
        
        Args:
            loan_id: ID del préstamo a rechazar
            rejected_by: ID del usuario que rechaza
            rejection_reason: Razón del rechazo (obligatorio)
            
        Returns:
            Loan rechazado
            
        Raises:
            ValueError: Si alguna validación falla
        """
        # 1. Buscar préstamo
        loan = await self.repository.find_by_id(loan_id)
        if not loan:
            raise ValueError(f"Préstamo con ID {loan_id} no encontrado")
        
        # 2. Validar que esté PENDING
        if not loan.is_pending():
            raise ValueError(
                f"El préstamo {loan_id} no está en estado PENDING. "
                f"Estado actual: {loan.status_id}. "
                f"Solo se pueden rechazar préstamos PENDING."
            )
        
        # 3. Validar que puede ser rechazado
        if not loan.can_be_rejected():
            raise ValueError(
                f"El préstamo {loan_id} no puede ser rechazado. "
                f"Verifique que no esté ya aprobado o cancelado."
            )
        
        # 4. Validar razón de rechazo (obligatoria)
        if not rejection_reason or not rejection_reason.strip():
            raise ValueError(
                "La razón del rechazo es obligatoria. "
                "Por favor, proporcione una explicación clara."
            )
        
        # 5. Actualizar préstamo a REJECTED
        loan.status_id = LoanStatusEnum.REJECTED.value
        loan.rejected_at = datetime.utcnow()
        loan.rejected_by = rejected_by
        loan.rejection_reason = rejection_reason.strip()
        
        # 6. Guardar
        rejected_loan = await self.repository.update(loan)
        
        # 7. Commit
        await self.session.commit()
        
        # Log de auditoría
        log_loan_rejected(
            loan_id=loan_id,
            user_id=loan.user_id,
            rejected_by=rejected_by,
            reason=rejection_reason
        )
        
        return rejected_loan
    
    # =============================================================================
    # MÉTODOS AUXILIARES
    # =============================================================================
    
    async def get_loan_by_id(self, loan_id: int) -> Optional[Loan]:
        """
        Obtiene un préstamo por su ID.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Loan si existe, None si no
        """
        return await self.repository.find_by_id(loan_id)
    
    async def list_loans(
        self,
        status_id: Optional[int] = None,
        user_id: Optional[int] = None,
        associate_user_id: Optional[int] = None,
        limit: int = 50,
        offset: int = 0
    ) -> tuple[list[Loan], int]:
        """
        Lista préstamos con filtros.
        
        Args:
            status_id: Filtrar por estado (opcional)
            user_id: Filtrar por cliente (opcional)
            associate_user_id: Filtrar por asociado (opcional)
            limit: Máximo de registros
            offset: Desplazamiento para paginación
            
        Returns:
            Tupla (lista de préstamos, total de registros)
        """
        loans = await self.repository.find_all(
            status_id=status_id,
            user_id=user_id,
            associate_user_id=associate_user_id,
            limit=limit,
            offset=offset
        )
        
        total = await self.repository.count(
            status_id=status_id,
            user_id=user_id,
            associate_user_id=associate_user_id
        )
        
        return loans, total
    
    async def update_loan(
        self,
        loan_id: int,
        amount: Optional[Decimal] = None,
        interest_rate: Optional[Decimal] = None,
        commission_rate: Optional[Decimal] = None,
        term_biweeks: Optional[int] = None,
        notes: Optional[str] = None
    ) -> Loan:
        """
        Actualiza un préstamo que está en estado PENDING.
        
        Solo se pueden actualizar préstamos PENDING (solicitudes no procesadas aún).
        Los campos permitidos son: amount, interest_rate, commission_rate, term_biweeks, notes.
        
        Validaciones:
        - Préstamo existe
        - Préstamo está en estado PENDING
        - Si se actualiza el monto, verificar crédito del asociado
        
        Args:
            loan_id: ID del préstamo a actualizar
            amount: Nuevo monto (opcional)
            interest_rate: Nueva tasa de interés (opcional)
            commission_rate: Nueva tasa de comisión (opcional)
            term_biweeks: Nuevo plazo en quincenas (opcional)
            notes: Nuevas notas (opcional)
            
        Returns:
            Préstamo actualizado
            
        Raises:
            ValueError: Si el préstamo no existe, no está PENDING, o validaciones fallan
        """
        # 1. Buscar préstamo
        loan = await self.repository.find_by_id(loan_id)
        if not loan:
            raise ValueError(f"Préstamo {loan_id} no encontrado")
        
        # 2. Validar estado PENDING
        if not loan.is_pending():
            raise ValueError(
                f"Solo se pueden actualizar préstamos en estado PENDING. "
                f"El préstamo {loan_id} está en estado {loan.status_id}"
            )
        
        # 3. Validar cambio de monto (si aplica)
        if amount is not None and amount != loan.amount:
            has_credit = await self.repository.check_associate_available_credit(
                loan.associate_user_id, amount
            )
            if not has_credit:
                raise ValueError(
                    f"El asociado {loan.associate_user_id} no tiene crédito disponible "
                    f"para el nuevo monto de ${amount}"
                )
            loan.amount = amount
        
        # 4. Actualizar campos permitidos
        if interest_rate is not None:
            loan.interest_rate = interest_rate
        if commission_rate is not None:
            loan.commission_rate = commission_rate
        if term_biweeks is not None:
            loan.term_biweeks = term_biweeks
        if notes is not None:
            # Agregar nota de actualización
            timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
            update_note = f"[ACTUALIZACIÓN {timestamp}] {notes}"
            loan.notes = f"{loan.notes}\n{update_note}" if loan.notes else update_note
        
        # 5. Guardar
        updated_loan = await self.repository.update(loan)
        await self.session.commit()
        
        # Log de auditoría
        log_loan_updated(loan_id=loan_id, user_id=loan.user_id)
        
        return updated_loan
    
    async def cancel_loan(
        self,
        loan_id: int,
        cancelled_by: int,
        cancellation_reason: str
    ) -> Loan:
        """
        Cancela un préstamo que está en estado ACTIVE.
        
        Al cancelar un préstamo activo:
        - El préstamo pasa a estado CANCELLED
        - Se libera el crédito del asociado (pending_payments_total se reduce)
        - Se guarda la razón de la cancelación
        - Los pagos ya realizados no se revierten (se mantienen como histórico)
        
        Validaciones:
        - Préstamo existe
        - Préstamo está en estado ACTIVE
        - Razón de cancelación obligatoria (mínimo 10 caracteres)
        
        TODO Sprint 4: Decidir si se requiere liquidación de pagos pendientes
        
        Args:
            loan_id: ID del préstamo a cancelar
            cancelled_by: ID del usuario que cancela
            cancellation_reason: Razón de la cancelación (obligatoria)
            
        Returns:
            Préstamo cancelado
            
        Raises:
            ValueError: Si el préstamo no existe, no está ACTIVE, o razón inválida
        """
        # 1. Buscar préstamo
        loan = await self.repository.find_by_id(loan_id)
        if not loan:
            raise ValueError(f"Préstamo {loan_id} no encontrado")
        
        # 2. Validar estado activo
        if not loan.is_active():
            raise ValueError(
                f"Solo se pueden cancelar préstamos en estado ACTIVE. "
                f"El préstamo {loan_id} está en estado {loan.status_id}"
            )
        
        # 3. Validar razón obligatoria
        if not cancellation_reason or not cancellation_reason.strip():
            raise ValueError("La razón de cancelación es obligatoria")
        
        if len(cancellation_reason.strip()) < 10:
            raise ValueError(
                "La razón de cancelación debe tener al menos 10 caracteres"
            )
        
        # 4. Actualizar a CANCELLED
        loan.status_id = LoanStatusEnum.CANCELLED.value
        loan.cancelled_at = datetime.utcnow()
        loan.cancelled_by = cancelled_by
        loan.cancellation_reason = cancellation_reason.strip()
        
        # 5. Guardar (transacción ACID)
        # NOTA: El trigger update_pending_payments_total_on_cancel() se ejecuta automáticamente
        # cuando status_id cambia a CANCELLED (5), liberando el crédito del asociado
        cancelled_loan = await self.repository.update(loan)
        
        # 6. Commit de la transacción (incluye trigger)
        await self.session.commit()
        
        # Log de auditoría
        log_loan_cancelled(
            loan_id=loan_id,
            user_id=loan.user_id,
            associate_user_id=loan.associate_user_id,
            amount=float(loan.amount),
            reason=cancellation_reason
        )
        
        return cancelled_loan


__all__ = ['LoanService']
